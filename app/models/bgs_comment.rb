class BgsComment < ActiveRecord::Base
  belongs_to :bgs
  belongs_to :player
end
