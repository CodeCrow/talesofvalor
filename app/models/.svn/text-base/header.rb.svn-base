class Header < ActiveRecord::Base
  has_many :skill_headers
  has_many :skills, :through => :skill_headers

  def write_to_pdf(_p)
    skheaders = self.skill_headers.sort { |x,y| x.cost <=> y.cost }
    
    _p.text "<b>"+self.name+"</b>", :font_size => 18, :justification => :center
    _p.text self.description, :font_size => 12

    for skh in skheaders
      skh.skill.write_to_pdf(_p,nil)
    end
  end
end
