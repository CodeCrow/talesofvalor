class Player < ActiveRecord::Base

  has_many :chars, ->{ order(:name) }
  belongs_to :active_char, :class_name => "Char", :foreign_key => "active_char_id"
  has_many :events, ->{ order(:date) }, :through => :registrations
  has_many :registrations
  has_many :player_logs, -> { order(ts: :desc) } 

  def self.grab(nukeuser)
    if nukeuser.name.length > 0
      name = nukeuser.name
    elsif nukeuser.username.length > 0
      name = nukeuser.username
    else
      name = nukeuser.user_email
    end
    
    perms = nukeuser.connection.select_one("select id from talesof_nuke1.nuke_subscriptions where userid=#{nukeuser.user_id}")
    
    player = Player.new({:name => name, :username => nukeuser.username, :email => nukeuser.user_email, :password => 'ignored', :acl => perms ? 'Staff' : 'Player', :game_started => Time.new.strftime("%d %b %Y")})
    player.save!
    return player
  end

  def staff?
    acl == 'Staff' || acl == 'Admin'
  end

  def admin?
    acl == 'Admin'
  end

  def can_edit?(c)
    admin? || c.player == self
  end

  def can_view?(c)
    staff? || c.player == self
  end

  def setactive(c,session)
    self.active_char_id = c
    self.save!
    if session[:user] == self
      session[:user].active_char_id = c
    end
  end

  def viewable(priv)
    priv = staff? unless priv != nil
    if priv
      headers = Header::find(:all)
    else
      headers = Header::find_by_sql("select h.* from headers h where h.hidden = 0 union select h.* from headers h, chars c, char_headers ch where c.player_id = #{self.id} and c.id = ch.char_id and ch.header_id = h.id union select h.* from headers h, grants g, chars c where c.player_id = #{self.id} and g.char_id = c.id and g.type='HeaderGrant' and g.correlated_id = h.id")
    end

    avail = { :headers => {}, :skills => {} }

    for h in headers
      avail[:headers][h.id] = true
      for s in h.skills
        avail[:skills][s.id] = true
      end
    end

    if priv
      skills = Skill::find(:all)
    else
      skills = Skill::find_by_sql("select s.* from skills s, skill_headers sh where sh.skill_id = s.id and (sh.header_id = 0 or sh.dabble = 1) union select s.* from skills s, char_skills cs, chars c where c.player_id = #{self.id} and cs.char_id = c.id and cs.skill_id = s.id union select s.* from skills s, grants g, chars c where c.player_id = #{self.id} and g.char_id = c.id and g.type = 'SkillGrant' and g.correlated_id = s.id")
    end

    for s in skills
      avail[:skills][s.id] = true
    end
    return avail
  end

end
