class SkillTag < Tag
  belongs_to :skill, :class_name => "Skill", :foreign_key => :foreign_id
end

