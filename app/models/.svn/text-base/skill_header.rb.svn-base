class SkillHeader < ActiveRecord::Base
  belongs_to :skill
  belongs_to :header

  def self.skillsbyheader
    sbyh = {}
    for skh in find_by_sql("select sh.* from skill_headers sh, skills s where s.id = sh.skill_id order by s.tag,sh.cost asc,s.name")
      if sbyh[skh.header_id]
        sbyh[skh.header_id].push(skh)
      else
        sbyh[skh.header_id] = [skh]
      end
    end
    return sbyh
  end
end
