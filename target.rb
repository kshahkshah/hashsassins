class Target < ActiveRecord::Base
  belongs_to :game
  belongs_to :assassin, class_name: User
  belongs_to :target,   class_name: User

  attr_accessible :assassin_id, :eliminated_at, :target_id
end