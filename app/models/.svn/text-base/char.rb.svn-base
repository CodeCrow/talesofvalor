class Char < ActiveRecord::Base
  has_many :char_skills
  has_many :skills, :through => :char_skills
  has_many :between_game_skills, :through => :char_skills, :source => :skill, :conditions => "bgs = 1"
  has_many :char_headers
  has_many :headers, :through => :char_headers
  has_many :char_origins
  has_many :origins, :through => :char_origins
  has_many :races, :through => :char_origins, :source => :origin, :conditions => "type = 'race'"
  has_many :backgrounds, :through => :char_origins, :source => :origin, :conditions => "type = 'background'"
  has_many :char_logs, :order => "ts desc"
  belongs_to :player

  def self.simplecreate(params,player,staff)
    msg = ''
    success = false
    char = nil
    begin
      transaction do
        char = Char.new(params[:char])
        
        if not staff
          char.cp_avail=20
          char.cp_spent=0
          char.cp_transferred=0
          char.visible_staff_notes = ''
          char.private_staff_notes = ''
          char.npc = false
          char.staff_attn = true
          char.picture_url = ''
        end

        if char.name.length == 0
          msg += "Name unspecified."
          raise
        end

        char.player = player
        char.save!

        cl = CharLog.new(:char => char, :entry => 'Created')
        cl.save!

        success = true
      end
    rescue RuntimeError
    rescue ActiveRecord::RecordNotSaved
      msg += 'Unable to save character'
    end
    return [success,msg,char]
  end

  def addoriginskill(skid, count)
    cs = CharSkill.find(:first, :conditions => { :char_id => self, :skill_id => skid })
    if not cs
      skill = Skill.find(skid)
      cs = CharSkill.new(:char => self, :skill => skill, :count => count)
      cs.save!
      grant = Grant.new(:char_id => self.id, :correlated_id => skill.id, :reason => "Race benefit", :type => 'SkillGrant')
      grant.save!
    else
      count += cs.count
      count = 1 if cs.skill.flag and cs.count > 1
      self.connection.update("update char_skills set count = #{count} where char_id=#{self.id} and skill_id=#{skid}")
    end
  end

  def addrace(params,staff)
    msg = ''
    success = false
    if not self.races.empty? and not staff
      return [false,"#{self.name} already has a race."]
    end
    begin
      transaction do
        if not params[:origin][:race] or params[:origin][:race].length == 0
          o = Origin.find(params[:origin][:race])
          if o.type != 'Race'
            msg += "Race not specified."
            raise
          elsif o.hidden and !session[:staff]
            msg += "Can't select hidden race"
            raise
          end
        end
	if CharOrigin.find(:first,:conditions => {:char_id => self, :origin_id => params[:origin][:race]})
	  msg += "Already have that race"
	  raise
	end
        crace = CharOrigin.new(:char => self, :origin_id => params[:origin][:race])
        crace.save!
        for os in crace.origin.origin_skills
	  self.addoriginskill(os.skill.id,os.count)
        end

        cl = CharLog.new(:char => self, :entry => 'Added race '+crace.origin.name)
        cl.save!

        success = true

	self.reload
      end
    rescue RuntimeError
    rescue ActiveRecord::RecordNotSaved
      msg += 'Unable to save character'
    end
    return [success,msg]
  end

  def addbackground(params,staff)
    msg = ''
    success = false
    if self.backgrounds.length >= (self.isfreilan() ? 2 : 1) and not staff
      return [false,"#{self.name} already has a background."]
    end
    begin
      transaction do
        if not params[:origin][:background] or params[:origin][:background].length == 0 or Origin.find(params[:origin][:background]).type == 'Race'
          msg += "Background not specified."
          raise 
        end
	if CharOrigin.find(:first,:conditions => {:char_id => self, :origin_id => params[:origin][:background]})
	  msg += "Already have that background"
	  raise
	end
        cback = CharOrigin.new(:char => self, :origin_id => params[:origin][:background])
        cback.save!
        if cback.origin.name == 'Barbarian' || cback.origin.name == 'Sidhe Kingdom' # free weapon
          if not params[:weapon] or Skill.find(params[:weapon]).tag != 'weapon'
            msg += "Improper weapon supplied for free weapon"
            raise 
          end
	  self.addoriginskill(params[:weapon],1)
        elsif cback.origin.name == 'Freilan Community'
	  self.addoriginskill(params[:freilan],1)
        end
        for os in cback.origin.origin_skills
	  self.addoriginskill(os.skill.id,os.count)
        end

        cl = CharLog.new(:char => self, :entry => 'Added background '+cback.origin.name)
        cl.save!

        success = true

	self.reload
      end
    rescue RuntimeError
    rescue ActiveRecord::RecordNotSaved
      msg += 'Unable to save character'
    end
    return [success,msg]
  end

  def nextcreatestep()
     if self.races.empty?
       return "addrace"
     else 
       if self.backgrounds.length < (self.isfreilan() ? 2 : 1)
         return "addbackground"
       else       
         return "pick"
       end
     end
  end

  def isfreilan()
    for r in self.races
      return true if r.name == 'Freilan'
    end
    return false
  end

  def isjack()
    return !CharSkill.find_by_sql("select cs.* from char_skills cs, skills s where s.id = cs.skill_id and upper(s.name) = 'JACK OF ALL TRADES' and cs.char_id=#{self.id}").empty?
  end

  def open_header(h)
    transaction do
      ch = CharHeader.new(:char => self, :header => h)
      ch.save!
      
      cl = CharLog.new(:char => self, :entry => "Opened #{h.name} header for #{h.cost} CPs")
      cl.save!

      cost = (self.isjack() and h.cost > 0) ? h.cost-1 : h.cost
      
      self.cp_spent += cost
      self.cp_avail -= cost
      self.save!
    end
  end

  def remove_header(h)
    transaction do
      skillstoberemoved = SkillHeader.find(:all, :conditions => "header_id = #{h.id.to_i}")
      skillmessage = ''
      @cskills = self.skillhash
      for skill in skillstoberemoved
        skid = skill[:skill_id].to_i
        skillmessage += String(skid) + ","
        if @cskills[skid]
          cl = CharLog.new(:char => self, :entry => String(skid) + ":" + @cskills.to_yaml)
          cl.save!      
          cl = CharLog.new(:char => self, :entry => skill.to_yaml)
          cl.save!
          self.cp_spent -= skill[:cost].to_int * @cskills[skid].count
          self.cp_avail += skill[:cost].to_int * @cskills[skid].count
        end
      end
      skillmessage = skillmessage.chomp(",")
      CharSkill.delete_all("char_id = #{self.id} AND skill_id IN (#{skillmessage})")

      CharHeader.delete_all("char_id = #{self.id} AND header_id = #{h.id}")
      #Go through @char.skillhash and combine that with self.skillcosts to figure out current totals
      currentTotal = 0
      #currentSkillCosts = self.skillcosts
      #self.skillhash.each do |k,v|  
      #  currentTotal += currentSkillCosts[v[:skill_id]] * v[:count]
      #end
      #old_spent = self.cp_spent

      cost = (self.isjack() and h.cost > 0) ? h.cost-1 : h.cost
      self.cp_spent -= cost
      self.cp_avail += cost
      self.save!
            
      cl = CharLog.new(:char => self, :entry => "Removed header #{h.name}.")
      cl.save!
    end
  end
  
  def pointcap
    return 20-self.cp_transferred
  end

  def skillhash
    skh = {}
    for sk in char_skills
      skh[sk.skill_id] = sk
    end
    return skh
  end

  def magicskills
    return !Skill.find_by_sql("select s.* from skills s, skill_headers sh, char_skills cs, headers h where s.id = sh.skill_id and sh.header_id = h.id and h.category like '%Magic%' and h.name not like '%Counter%' and cs.char_id = #{self.id} and cs.skill_id=s.id").empty?
  end

  def magicheaders
    return !Header.find_by_sql("select h.* from headers h, char_headers ch where h.category like '%Magic%' and h.name not like '%Counter%' and ch.header_id = h.id and ch.char_id = #{self.id}").empty?
  end

  def hasresistmagic
    return !CharSkill.find_by_sql("select cs.* as count from char_skills cs, skills s where s.id = cs.skill_id and s.name = 'Resist Magic' and cs.char_id = #{self.id}").empty?
  end

  def bgs_counts(event)
    counts = {}
    for cs in CharSkill.find_by_sql("select cs.* from char_skills cs, skills s where s.id = cs.skill_id and s.bgs = 1 and cs.char_id = #{self.id}")
      counts[cs.skill_id] = [0,cs.count]
    end
    for bgs in Bgs.find_by_sql("select char_id,skill_id,event_id,sum(count) as count from bgs where event_id = #{event} and char_id = #{self.id} group by skill_id")
      if not counts[bgs.skill_id]
        counts[bgs.skill_id] = [bgs.count,0]
      else
        counts[bgs.skill_id][0] = bgs.count
      end
    end
    return counts
  end

  def skillcosts
    skcosts = {}
    for sk in SkillHeader.find_by_sql("select sh.skill_id,sh.header_id,sh.cost from skill_headers sh where sh.header_id=0 union select sh.skill_id,sh.header_id,min(sh.cost) as cost from skill_headers sh, char_headers ch where sh.header_id = ch.header_id and ch.char_id = #{id} group by skill_id")
      skcosts[sk.skill_id] = sk.cost
    end
    for sk in SkillHeader.find_by_sql("select sh.skill_id,sh.header_id,min(sh.cost) as cost from skill_headers sh, grants g where g.char_id = #{id} and g.type = 'SkillGrant' and sh.skill_id = g.correlated_id group by sh.skill_id")
      if !skcosts[sk.skill_id]
        skcosts[sk.skill_id] = sk.cost
      end
    end
    skcosts[:dabble] = []
    for sk in SkillHeader.find(:all, :conditions => "dabble = 1")
      if !skcosts[sk.skill_id]
        skcosts[sk.skill_id] = sk.cost+1
        skcosts[:dabble].push(sk)
      end
    end
    skcosts[:dabble].sort! {|a,b| a.skill.name <=> b.skill.name }
    Rule.apply_to_char(self,skcosts)
    return skcosts
  end

  def headercosts
    hcosts = {}
    isj = self.isjack()
    for h in Header.find(:all)
#      hcosts[h.id] = h.cost
      hcosts[h.id] = ((isj and h.cost > 0) ? h.cost-1 : h.cost)
    end
    return hcosts
  end

  def write_to_pdf(_p,detail,event)
    cheaders = self.headers
    cskills = self.skillhash
    sbyh = SkillHeader.skillsbyheader
    origins = self.origins
    cskillsleft = cskills.keys

    _p.text self.name, :font_size => 24, :justification => :center
    _p.text "\nCP Available: #{self.cp_avail} CP Spent: #{self.cp_spent} CP Total: #{self.cp_avail+self.cp_spent}\n\n", :font_size => 12, :justification => :left
    for o in self.origins
      _p.text o.type.to_s.capitalize + ': '+o.name, :font_size => 12, :justification => :left
    end
    _p.text "\n\n"

    _p.text "Skills", :font_size => 18
    _p.text "Open Skills", :font_size => 16, :left => 10
    for skh in sbyh[0]
      if cskills[skh.skill_id]
        cskillsleft.delete(skh.skill_id)
        if (skh.skill.flag?)
          _p.text skh.skill.name, :font_size => 12, :left => 20
        else
          _p.text cskills[skh.skill_id].count.to_s+' '+skh.skill.name, :font_size => 12, :left => 20
        end
      end
    end
    
    for h in cheaders
      _p.text h.name, :font_size => 16, :left => 10
      if sbyh[h.id]
        for skh in sbyh[h.id]
          if cskills[skh.skill_id] && cskillsleft.delete(skh.skill_id)
            if (skh.skill.flag?)
              _p.text skh.skill.name, :font_size => 12, :left => 20
            else
              _p.text cskills[skh.skill_id].count.to_s+' '+skh.skill.name, :font_size => 12, :left => 20
            end
          end
        end
      end
    end

    if !cskillsleft.empty?
      _p.text "Other Skills", :font_size => 16, :left => 10
      for sk in cskillsleft.collect {|s| Skill.find(s) }
        if sk.flag?
          _p.text sk.name, :font_size => 12, :left => 20
        else
          _p.text cskills[sk.id].count.to_s+' '+sk.name, :font_size => 12, :left => 20
        end
      end
    end

    _p.text "\n\nPlayer Notes:", :font_size => 14
    _p.text self.player_notes.gsub(/\342|\200|\234|\235|\231|\303\|\240|\246|\206|\222/,''), :font_size => 10, :left => 10

    _p.text "\n\nVisible Staff Notes:", :font_size => 14
    _p.text self.visible_staff_notes.gsub(/\342|\200|\234|\235|\231|\303\|\240|\246|\206|\222/,''), :font_size => 10, :left => 10

    if event != 0
      _p.text "\n\n"
      _p.text "Between Game Skills", :font_size => 18
      for bgs in Bgs.find(:all, :conditions => ["event_id = ? and char_id = ?",event,self.id])
        _p.text "\n"
        bgs.write_to_pdf(_p)
      end

      _p.text "\n\n"
      _p.text "Messages", :font_size => 18
      for em in EventMessage.find(:all, :conditions => ["event_id = ? and char_id = ?", event, self.id])
        _p.text "\n"
        em.write_to_pdf(_p)
      end
    end

    if detail
      _p.start_new_page
      _p.text "<b>Skill Descriptions</b>", :font_size => 14
      for sk in cskills.values
        sk.skill.write_to_pdf(_p,sk.count)
      end
    end

  end


  def self.resetpointcap(obj)
    obj.connection.update("update chars set cp_transferred=0")
  end

end
