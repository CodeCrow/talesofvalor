class CharSkill < ActiveRecord::Base
  belongs_to :char
  belongs_to :skill
end
