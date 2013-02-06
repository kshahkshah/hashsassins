require 'tweetstream'
require './db_connection'

# keep a listener open for each open game...
admin = User.where(nickname: 'Hashsassins').first

TweetStream.configure do |config|
  config.consumer_key       = "" # YOU'LL NEED TO PROVIDE THIS
  config.consumer_secret    = "" # YOU'LL NEED TO PROVIDE THIS
  config.oauth_token        = admin.token
  config.oauth_token_secret = admin.secret
  config.auth_method        = :oauth
  config.parser             = :json_gem
end

# Instead of just accessing the object through TweetStream, I did this...
Twitter.configure do |config|
  config.consumer_key       = "" # YOU'LL NEED TO PROVIDE THIS
  config.consumer_secret    = "" # YOU'LL NEED TO PROVIDE THIS
  config.oauth_token        = admin.token
  config.oauth_token_secret = admin.secret
end

puts "spinning up..."

TweetStream::Daemon.new('hashsassins').userstream do |status|
  if status.text.match(/@Hashsassins/) || status.text.match(/@hashsassins/)

    ActiveRecord::Base.establish_connection({
      database: 'assassins',
      adapter:  'postgresql',
      encoding: 'unicode',
      pool:     5,
      username: 'root',
      password: '',
      reconnect: true
    })

    puts "received a message... #{status.text}"

    # who?
    handle = status.user.handle
    puts "from #{handle}"

    user = User.find_by_nickname(handle) || User.create(nickname: handle)
    puts "user id #{user.id}"

    # normalize the message
    text = status.text.downcase

    # identify the game from a hashtag
    hashtags = text.scan(/(?<=#)[[:alnum:]]+/)
    puts "hashtags are #{hashtags.join(' ')}"

    # just take the first for now...
    if hashtags
      @game = hashtags.map{ |h| Game.find_by_hashtag(h) }.compact.first
      puts "game is #{@game.inspect}"
    end

    # PREPARE A NEW GAME
    if text.match(/cry havoc/)
      # beware the ides of march
      hashtag = hashtags.first

      if hashtag
        # hashtag in use
        if Game.where(hashtag: hashtag).where("status <> 'complete'").first
          Twitter.update("@#{handle} that hashtag is currently in use. Please pick another.")
          puts "can't create game, hashtag in use"

        # hashtag not in use; create
        else
          Game.create(hashtag: hashtag, moderator_id: user.id)
          Twitter.update("@#{handle} welcome. Your game's hashtag is ##{hashtag}.")
          Twitter.update("Assassins wishing to join should tweet at me with reporting for duty ##{hashtag}")
          puts "creating a game ##{hashtag}"

        end
      else
        Twitter.update("@#{handle} please provide me a hashtag to identify your game")
        puts "can't create game, no hashtag provided"

      end
    end

    # FROM NOW ON WE NEED A GAME
    if !@game
      puts "no game found via hashtag, report help instead..."
      Twitter.update("@#{handle} I'm a robot and am not smart enough to help you yet. Ask @whistlerbrk")

    else
      puts "game found, reading input..."

      # BEGIN A GAME
      if text.match(/the die is cast/)
        puts "game start requested..."

        # make sure they are the moderator
        if @game.moderator.nickname == handle
          puts 'starting game...'
          @game.start!
          Twitter.update("The die is cast! Blood shall run in the vulgar streets! ##{@game.hashtag}")
          Twitter.update("Make sure you're following me back for your target assignments ##{@game.hashtag}")

          @game.targets.each do |target|
            Twitter.direct_message_create(target.assassin.nickname, "Hello agent @#{target.assassin.nickname}. Find and eliminate @#{target.target.nickname}")
          end

          Twitter.update("message me 'target eliminated' with ##{@game.hashtag} upon completion of assignment")
          puts 'game started!'

        # not the moderator? wtf...
        else
          puts "user @#{handle} is not the moderator of #{@game.id} hashtag ##{@game.hashtag}, #{@game.moderator.nickname} is."
          Twitter.update("@#{handle} you are not this games moderator!")

        end

      # END THE GAME
      elsif text.match(/veni, vidi, vici/)
        # make sure they are the moderator
        if @game.moderator.nickname == handle
          @game.end!
          Twitter.update("All good things must come to an end. ##{@game.hashtag}")
          Twitter.update("Congratulations @#{@game.winner} you are the winner with #{@game.winner_kills} kills. ##{@game.hashtag}")
          puts 'game complete!'

        # not the moderator? wtf...
        else
          Twitter.update("@#{handle} you are not this games moderator!")
          puts "user @#{handle} is not the moderator of #{@game.id} hashtag ##{@game.hashtag}, #{@game.moderator.nickname} is."
        end

      # REPORT BACK A GAME STATS
      elsif text.match(/soothsay/)
        if @game.new?
          Twitter.update("@#{handle} That game has yet to begin. The moderator is @#{@game.moderator.nickname}")
        elsif @game.started?
          Twitter.update("@#{handle} That game is currently in progress. The leader has #{@game.winner_kills} kills.")
        elsif @game.complete?
          Twitter.update("@#{handle} That game is over #{@game.winner} won with #{@game.winner_kills} kills")
        end

      # JOIN AN EXISTING GAME
      elsif text.match(/reporting for duty/)
        puts 'a new player wants to join the game!'

        if !@game.new?
          # reply sorry too late! next time!
          Twitter.update("@#{handle} Sorry that game has already begun or is complete!")

        else
          # follow them back
          Twitter.follow(handle)

          # record
          if @game.has_user?(user)
            Twitter.update("@#{handle} patience patience mon capitan! You're already part of the game.")

          else
            if @game.join(user)
              # make sure they know they need to follow us
              Twitter.update("@#{handle} Welcome agent #{handle}. Make sure you're following me back to receive target information.")

            else
              puts "problem joining a game"
              Twitter.update("@#{handle} There was a problem joining you to the game. Stand by!")
              Twitter.update("@whistlerbrk There was a problem joining @#{handle} to a game ##{@game.hashtag}! Help them out!")

            end

          end

        end

      # WHO IS MY OPPONENT
      elsif text.match(/name the ill fated/)
        target = @game.target_for(user)
        Twitter.direct_message_create(handle, "As of #{Time.now.strftime("%H:%M")} your target is @#{target.nickname} ##{@game.hashtag}")

      # KILL AN OPPONENT
      elsif text.match(/target eliminated/)
        puts "someone is reporting a kill..."

        # guy.. the game hasn't even started...
        if @game.new?
          puts "game hasn't started..."
          Twitter.update("@#{handle} The time of action is not yet at hand... ##{@game.hashtag}")

        # reply crazy killer! game has finished!
        elsif @game.complete?
          puts "game finished already..."
          Twitter.update("@#{handle} Your dedication to the cause is noted, but the time to kill has passed.")

        # reply vigilante, you're not even part of the game!
        elsif !@game.has_user?(user)
          Twitter.update("@#{handle} a plague upon you brigand and vigilante. You're not part of the game!")

        # dead for a ducat
        else
          # find their target & record
          @game.record_kill_for(user)

          # give them their new target...
          if target = @game.target_for(user)
            puts "new target is #{target.nickname}..."
            Twitter.direct_message_create(handle, "As of #{Time.now.strftime("%H:%M")} your new target is @#{target.nickname} ##{@game.hashtag}")

            puts "making kill announcement..."
            Twitter.update("Another one bites the dust. @#{target.nickname} eliminated ##{@game.hashtag}")

          else
            puts "no new targets to assign..."
            Twitter.direct_message_create(handle, "All targets eliminated")

          end

        end

      end
    end

  end
end

puts "all good things must come to an end, exiting..."
