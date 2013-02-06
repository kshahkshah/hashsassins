class User < ActiveRecord::Base
  has_many :games, :foreign_key => :moderator_id

  attr_accessible :uid, :nickname, :name, :token, :secret
end