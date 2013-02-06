class Game < ActiveRecord::Base
  include Workflow
  workflow_column :status

  has_many :targets
  belongs_to :moderator, class_name: User, foreign_key: :moderator_id

  validates_uniqueness_of :hashtag
  attr_accessible :moderator_id, :hashtag, :status

  workflow do
    state :new do
      event :start, transitions_to: :started
    end
    state :started do
      event :end, transitions_to: :complete
    end
    state :complete do
      event :restart, transitions_to: :started
    end
  end

  # a = [1, 2, 3, 4, 5, 6, 7, 8]
  # b = a.shuffle;
  # b << b.first;
  # b.each_cons(2).to_a
  def start
    @targets_a = self.targets.map(&:assassin_id)
    @targets_b = @targets_a.shuffle
    @targets_b << @targets_b.first

    @targets_b.each_cons(2).to_a.each do |pair|
      target = self.targets.where(assassin_id: pair[0]).first
      target.target_id = pair[1]
      target.save
    end
  end

  def winner_kills
    0
  end

  def has_user?(user)
    self.targets.where(assassin_id: user.id).first.nil? ? false : true
  end

  def join(user)
    self.targets.create(assassin_id: user.id)
  end

  def record_kill_for(user)
    # get the kill, mark it
    kill = self.targets.where(assassin_id: user.id).first
    kill.eliminated_at = Time.now
    kill.save
    
    # get the kill that useless target was suppose to perform and reassign it
    new_kill = self.targets.where(assassin_id: kill.target_id).first
    if new_kill
      new_kill.assassin_id = user.id
      new_kill.save
    end

  end

  def target_for(user)
    self.targets.where(assassin_id: user.id).first.target rescue nil
  end

end