class Rule < ActiveRecord::Base
  belongs_to :skill

  def Rule.apply_to_char(char, cskills)

    rules = Rule.find_by_sql("select r.* from rules r, char_origins co where co.char_id=#{char.id} and co.origin_id = r.correlated_id and r.type = 'OriginRule'")
    rules += Rule.find_by_sql("select r.* from rules r, char_headers ch where ch.char_id=#{char.id} and ch.header_id = r.correlated_id and r.type = 'HeaderRule'")
    rules += Rule.find_by_sql("select r.* from rules r, char_skills cs where cs.char_id=#{char.id} and cs.skill_id = r.correlated_id and r.type = 'SkillRule'")
    for r in rules
      if cskills[r.skill_id]
	cskills[r.skill_id] = r.new_cost
      end
    end
  end
end

class OriginRule < Rule
  def prereq
    Origin.find(correlated_id)
  end
end

class HeaderRule < Rule
  def prereq
    Header.find(correlated_id)
  end
end

class SkillRule < Rule
  def prereq
    Skill.find(correlated_id)
  end
end
