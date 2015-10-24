class Event < ActiveRecord::Base
  has_many :registrations
  has_many :attendances

  def self.next()
    return self.find(:first, :conditions => ["date > now()"], :order => "date asc")
  end

  def self.last()
    return self.find(:first, :conditions => ["date < now()"], :order => "date desc")
  end

  def future?
    return self.date > Time.new
  end

  def skillscoming(sortorder)
    if sortorder == 'name'
      order = 's.name'
    else
      order = 'count desc'
    end
    if self.future?
      return Skill.find_by_sql("select s.id,s.name,sum(cs.count) as count from skills s, char_skills cs, chars c, players p, registrations r where r.event_id = #{self.id} and r.player_id = p.id and p.active_char_id = c.id and not c.npc and cs.char_id = c.id and cs.skill_id = s.id group by s.id order by #{order}")
    else
      return Skill.find_by_sql("select s.id,s.name,sum(cs.count) as count from skills s, char_skills cs, chars c, attendances a where a.event_id = #{self.id} and a.char_id = c.id and not c.npc and cs.char_id = c.id and cs.skill_id = s.id group by s.id order by #{order}")
    end
  end

  def skillscomingbychar(skill)
    if self.future?
      return Char.find_by_sql("select c.id,c.name,cs.count from char_skills cs, chars c, players p, registrations r where r.event_id = #{self.id} and r.player_id = p.id and p.active_char_id = c.id and not c.npc and cs.char_id = c.id and cs.skill_id = #{skill.id} order by cs.count desc")
    else
      return Char.find_by_sql("select c.id,c.name,cs.count from char_skills cs, chars c, attendances a where a.event_id = #{self.id} and a.char_id = c.id and not c.npc and cs.char_id = c.id and cs.skill_id = #{skill.id} order by cs.count desc")
    end
  end

  def write_to_pdf(_p,players,staff)
    _p.text "Registration List", :font_size => 24, :justification => :center
    _p.text self.name, :font_size => 24, :justification => :center
    _p.text "Printed "+Time.now.asctime, :font_size => 18, :justification => :center
    ptable = PDF::SimpleTable.new
    ptable.data = players.map {|p| {"Name" => p[:player].name, "Character" => (p[:char] ? p[:char].name : "?"), "Here" => "", "Mealplan" => p[:mealplan], "Cabin" => p[:cabin], "Notes" => p[:notes]}}
    ptable.column_order = ["Name","Character","Here","Mealplan","Cabin","Notes"]
    ptable.columns["Mealplan"] = PDF::SimpleTable::Column.new("Mealplan") { |col|
      col.heading = "Mealplan"
      col.justification = :center
    }
    ptable.columns["Notes"] = PDF::SimpleTable::Column.new("Notes") { |col|
      col.heading = "Notes"
      col.width=100
    }
    ptable.protect_rows = 3
    ptable.title = "Players"
    ptable.title_font_size = 18
    ptable.render_on(_p)

    stable = PDF::SimpleTable.new
    stable.data = staff.map {|s| {"Name" => s[:player].name, "Character" => (s[:char] ? s[:char].name : "?"), "Cabin" => s[:cabin], "Notes" => s[:notes]} }
    stable.column_order = ["Name","Character","Cabin","Notes"]
    stable.columns["Notes"] = PDF::SimpleTable::Column.new("Notes") { |col|
      col.heading = "Notes"
      col.width=100
    }
    stable.protect_rows = 3
    stable.title = "Staff"
    stable.title_font_size = 18
    stable.render_on(_p)
  end
end
