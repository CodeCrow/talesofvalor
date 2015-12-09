class Bgs < ActiveRecord::Base
  belongs_to :event
  belongs_to :player
  belongs_to :char
  belongs_to :skill
  belongs_to :answering_player, :class_name => "Player", :foreign_key => :answering_player_id

end
