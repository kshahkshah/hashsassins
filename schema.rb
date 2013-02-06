require './db_connection'

class CreateHashsassins < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.integer :id
      t.integer :uid
      t.string :nickname
      t.string :name
      t.string :token
      t.string :secret
      t.timestamps
    end

    create_table :games do |t|
      t.integer :id
      t.integer :moderator_id
      t.string  :hashtag
      t.string  :status
      t.timestamps
    end

    create_table :targets do |t|
      t.integer :id
      t.integer :game_id
      t.integer  :assassin_id
      t.integer  :target_id
      t.timestamp :eliminated_at
      t.timestamps
    end
  end

  def self.down
    drop_table :users
    drop_table :games
    drop_table :targets
  end

end

CreateHashsassins.down
CreateHashsassins.up
