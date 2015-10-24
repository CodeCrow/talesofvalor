class OriginSkill < ActiveRecord::Base
  belongs_to :skill
  belongs_to :origin
end
