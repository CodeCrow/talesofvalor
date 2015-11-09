class Skill < ActiveRecord::Base
  has_many :skill_headers
  has_many :headers, :through => :skill_headers
  has_many :magicheaders, -> { where("category LIKE '%Magic%' AND name not LIKE '%Counter%'")}, 
    class_name: "Header", 
    source: "header", 
    through:  :skill_headers

  def write_to_pdf(_p,num)
    if num
      cost = num
    else
      skheaders = self.skill_headers
      if skheaders.empty?
        cost = 0
      else
        cost = skheaders[0].cost
      end
    end
    _p.text "<b>"+self.name+" ("+cost.to_s+")</b>\n"
    _p.text self.description
  end

end
