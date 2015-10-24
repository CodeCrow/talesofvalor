require 'pdf/writer'

class CharsController < ApplicationController
  helper :chars
  helper :origins

  def index
    list
    render :action => 'list'
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :action => :list }

  verify :session => :user, :redirect_to => { :controller => :players, :action => :login }, :add_flash => {:notice => "Must log in before viewing or modifying characters"}

  def list
    if !session[:chars]
      session[:chars] = Array.new
    end
    filter = params[:filter] ? params[:filter] : 'all'
    if filter == 'pc'
      @title = "PCs"
      @char_pages, @chars = paginate :chars, :per_page => 30, :order => 'name', :conditions => "npc = 0"
    elsif filter == 'npc'
      @title = "NPCs"
      @char_pages, @chars = paginate :chars, :per_page => 30, :order => 'name', :conditions => "npc = 1"
    elsif filter == 'attn'
      @title = "Need Attention"
      @char_pages, @chars = paginate :chars, :per_page => 30, :order => 'name', :conditions => "staff_attn = 1"
    elsif filter == 'name'
      @title = "Name like #{params[:filtervalue]}"
      @char_pages, @chars = paginate :chars, :per_page => 30, :order => 'name', :conditions => ["name like ?","%"+params[:filtervalue]+"%"]
    elsif filter == 'origin'
      o = Origin.find(params[:filtervalue])
      @title = "Origin #{o ? o.name : '???'}"
      sql = "select c.* from chars c, char_origins co where co.char_id = c.id and co.origin_id=#{params[:filtervalue].to_i} group by c.id"
      @char_pages, @chars = paginate_by_sql Char, sql, 30
    elsif filter == 'header'
      o = Header.find(params[:filtervalue])
      @title = "Header #{o ? o.name : '???'}"
      sql = "select c.* from chars c, char_headers ch where ch.char_id = c.id and ch.header_id=#{params[:filtervalue].to_i} group by c.id"
      @char_pages, @chars = paginate_by_sql Char, sql, 30
    elsif filter == 'skill'
      params[:filtervalue]
      @title = "has skill like #{params[:filtervalue]}"
      sql = "select c.* from chars c, char_skills cs, skills s where cs.char_id = c.id and cs.skill_id=s.id and s.name like '%#{Char.connection.quote_string(params[:filtervalue])}%' group by c.id"
      @char_pages, @chars = paginate_by_sql Char, sql, 30
    elsif filter == 'selected'
      @title = "Selected"
      @char_pages = Paginator.new self, session[:chars].size, 30, params[:page]
      @chars = session[:chars][@char_pages.current.offset,
                              (@char_pages.current.offset+@char_pages.items_per_page > session[:chars].size ?
                               session[:chars].size - @char_pages.current.offset :
                               @char_pages.items_per_page)]
    else
      @title = "All"
      @char_pages, @chars = paginate :chars, :per_page => 30, :order => 'name'
    end
    if @chars.size == 1
      redirect_to :controller => :chars, :action => :show, :id => @chars[0].id
    end
    @tags = CharTag.allTags()
  end

  def pick
    @char = Char.find(params[:id])
    @cheaders = @char.headers
    @cskills = @char.skillhash
    @cskillsleft = @char.skillhash.keys
    @costs = @char.skillcosts
    @sbyh = SkillHeader.skillsbyheader
    @hcosts = @char.headercosts
    @dabbles = @costs[:dabble]
    @grants = Grant.find(:all, :conditions => "char_id = #{@char.id} and type = 'SkillGrant'").collect {|g| Skill.find(g.correlated_id)}
    @grants.compact!
    @hgrants = Grant.find(:all, :conditions => "char_id = #{@char.id} and type = 'HeaderGrant'").collect {|g| g.correlated_id }
  end

  def show
    @char = Char.find(params[:id])
    @cheaders = @char.headers
    @cskills = @char.skillhash
    @sbyh = SkillHeader.skillsbyheader
    @origins = @char.origins
    @cskillsleft = @cskills.keys
    @logs = CharLog.find(:all, :conditions => ["char_id=?",@char.id], :limit => 3, :order => "ts desc")
  end

  def getlog
    logs = CharLog.find(:all, :limit => 100, :offset => 3, :order => "ts desc", :conditions =>  ["char_id=?",params[:id]])
    render :partial => "log", :locals => {:logs => logs, :start => false}
  end

  def brief
    @char = Char.find(params[:id])
    @cheaders = @char.headers
    @cskills = @char.skillhash
    @sbyh = SkillHeader.skillsbyheader
    @origins = @char.origins
    @cskillsleft = @cskills.keys
  end

  def new
    @char = Char.new
    @char.npc = session[:staff] ? true : false
    @char.cp_avail=20
  end

  def create
    result = Char.simplecreate(params,session[:user],session[:staff])

    @char = result[2]

    if result[0]
      flash[:notice] = 'Char was successfully created.'
      redirect_to :action => (params[:commit] =~ /Continue/ ? @char.nextcreatestep() : 'show'), :id => @char.id
    else
      flash[:notice] = result[1] + '<br>Error creating character'
      render :action => 'new'
    end
  end

  def edit
    @char = Char.find(params[:id])
  end

  def editdetails
    @char = Char.find(params[:id])
  end

  def addrace
    @char = Char.find(params[:id])
    if session[:staff]
      @origins = Origin.find(:all,:order => :name, :conditions => {:type => 'Race'}).collect {|o| [o.name,o.id]}
    else
      @origins = Origin.find(:all,:order => :name, :conditions => {:type => 'Race', :hidden => false}).collect {|o| [o.name,o.id]}
    end

    have = {}
    @char.races.each {|b| have[b.id] = 1 }
    @origins.delete_if {|b| have[b[1]] }
  end

  def doaddrace
    @char = Char.find(params[:id])
    result = @char.addrace(params,session[:staff])
    if result[0]
      flash[:notice] = 'Race was successfully added.'
      redirect_to :action => (params[:commit] and params[:commit].include?("Continue") ? @char.nextcreatestep() : 'show'), :id => @char
    else
      render :action => 'addrace'
    end
  end

  def addbackground
    @char = Char.find(params[:id])
    if session[:staff]
      @origins = Origin.find(:all,:order => :name, :conditions => {:type => 'Background'}).collect {|o| [o.name,o.id]}
    else
      @origins = Origin.find(:all,:order => :name, :conditions => {:type => 'Background', :hidden => false}).collect {|o| [o.name,o.id]}
    end

    have = {}
    @char.backgrounds.each {|b| have[b.id] = 1 }
    @origins.delete_if {|b| have[b[1]] }
  end

  def doaddbackground
    @char = Char.find(params[:id])
    result = @char.addbackground(params,session[:staff])
    if result[0]
      flash[:notice] = 'Background was successfully added.'
      redirect_to :action => (params[:commit] and params[:commit].include?("Continue") ? @char.nextcreatestep() : 'show'), :id => @char
    else
      flash[:notice] = result[1]
      redirect_to :action => 'addbackground', :id => @char
    end
  end

  def update
    @char = Char.find(params[:id])
    if not session[:staff]
      for x in [:cp_spent, :cp_avail, :cp_transferred, :visible_staff_notes, :private_staff_notes, :staff_attn, :npc, :player_id]
        params.delete(x)
      end
    end
    if @char.update_attributes(params[:char])
      if @char.player_id != session[:user].id
        CharLog.new(:char => @char, :entry => "Character updated by #{session[:user].name}").save!
      else
        CharLog.new(:char => @char, :entry => 'Character updated').save!
      end
      flash[:notice] = 'Char was successfully updated.'
      redirect_to :action => (params[:commit] and params[:commit].include?("Continue") ? @char.nextcreatestep() : 'show'), :id => @char
    else
      render :action => 'edit'
    end
  end

  def reset
    @char = Char.find(params[:id])
    if Attendance.count(:conditions => {:char_id => @char.id}) > 1 and not session[:staff]
      flash[:notice] = 'Cannot reset character after attending more than 1 event'
      redirect_to :action => :show, :id => @char
    else
      flash[:notice] = 'Character reset'
      @char.cp_avail += @char.cp_spent
      @char.cp_spent = 0
      @char.save!
      CharSkill.delete_all("char_id = #{params[:id]}")
      CharHeader.delete_all("char_id = #{params[:id]}")
      CharOrigin.delete_all("char_id = #{params[:id]}")
      Grant.delete_all("char_id = #{params[:id]}")
      cl = CharLog.new(:char => @char, :entry => 'Reset')
      cl.save!
      redirect_to :action => :edit, :id => @char
    end
  end

  def steal
    @char = Char.find(params[:id])
    @player = Player.find(params[:newowner])
    oldowner = @char.player
    if oldowner != nil
      flash[:notice] = "Moved " + @char.name + " from "+oldowner.name+" to "+@player.name+"."
      if oldowner.active_char == @char
        if oldowner.chars.length == 1
          oldowner.active_char = nil
          oldowner.save!
        else
          for c in oldowner.chars
            if c != @char
              oldowner.active_char = c
              oldowner.save!
              break
            end
          end
        end
        if oldowner == session[:user]
          session[:user].active_char = oldowner.active_char
        end
      end
    else
      flash[:notice] = "Assigned "+@char.name + " to "+@player.name+"."
    end
    CharLog.new(:char => @char, :entry => flash[:notice]).save!
    @char.player = @player
    @char.save!
    @player.active_char = @char
    session[:user].active_char = @char if @player == session[:user]
    @player.save!
    redirect_to :controller => :players, :action => 'list'
  end

  def dopick
    @char = Char.find(params[:id])
    @cheaders = @char.headers
    @cskills = @char.skillhash
    flash[:notice] = '';

    # determine if we're a resistmagic kinda guy
    @rmskill = Skill.find(:first, :conditions => "name = 'Resist Magic'")
    if @cskills[@rmskill.id]
      magicstatus = 1   # resist magic 
    else
      if @char.magicheaders
        #flash[:notice] += "Magic Headers: "+(mh.collect {|h| h.name}).join(" ")+"<br>"
        magicstatus = -1  # magic
      else
        if @char.magicskills
          #flash[:notice] += "Magic Skills: "+(ms.collect {|s| s.name}).join(" ")+"<br>"
          magicstatus = -1  # magic
        else
          #flash[:notice] += "No allegiance<br>"
          magicstatus = 0   # haven't declared allegiance yet
        end
      end
    end

    costs = @char.skillcosts
    totalcost = 0
    purchases = []

    for sid in params[:picks].keys
      isid = sid.to_i
      if costs[isid]
        curcount = @cskills[isid] ? @cskills[isid].count : 0
        delta = params[:picks][sid].to_i - curcount
        s = Skill.find(sid)
        if magicstatus == -1 and s.id == @rmskill.id and delta > 0
          flash[:notice] += "Cannot purchase Resist Magic; Character has magic skills or headers<br>"
        elsif magicstatus == 1 and not (mh = s.magicheaders).empty? and delta > 0
          flash[:notice] += "Cannot purchase #{s.name}; Character has Resist Magic<br>"
        elsif delta < 0 and not session[:staff]
          flash[:notice] += "Cannot reduce " + Skill.find(sid).name + " count"
          params[:picks][sid] = curcount.to_s
        elsif delta != 0
          flash[:notice] += "Purchase " + delta.to_s + " " + Skill.find(sid).name + " for " + (delta * costs[isid]).to_s + " CPs<br>"
          totalcost += delta * costs[isid]
          purchases.push(sid)
          if s.id == @rmskill.id
            magicstatus = 1   # purchasing resist magic?
          elsif mh
            magicstatus = -1  # purchasing magic skills
          end
        end
      else
        if not @cskills[isid] or params[:picks][sid].to_i != @cskills[isid].count
          flash[:notice] += "Cannot purchase skill id #{sid}<br>"
        end
      end
    end

    if not purchases.empty?
      if totalcost <= @char.cp_avail
        @char.cp_avail -= totalcost
        @char.cp_spent += totalcost
        @char.save!

        for sid in purchases
          isid = sid.to_i
          if @cskills[isid]
            if @cskills[isid].count != params[:picks][sid].to_i
              #flash[:notice] += @cskills[isid].skill.name + ' count set to ' + params[:picks][sid] + '<br>'
              # doesn't understand tables with two primary keys!
              if params[:picks][sid].to_i == 0
                CharSkill.delete_all("char_id=#{@char.id} and skill_id=#{isid}")
              else
                @char.connection.update("update char_skills set count = #{params[:picks][sid].to_i} where char_id=#{@char.id} and skill_id=#{isid}")
              end
            end
          elsif params[:picks][sid].to_i > 0
            # @sk = Skill.find(sid)
            #flash[:notice] += @sk.name + ' count set to ' + params[:picks][sid] + ' from 0<br>'
            @cs = CharSkill.new(:char_id => @char.id, :skill_id => sid, :count => params[:picks][sid])
            @cs.save!
          end
        end
        cl = CharLog.new(:char => @char, :entry => flash[:notice])
        cl.save!
      else
        flash[:notice] += "Cost exceeds available CPs"
      end
    end
    redirect_to :action => (params[:commit] =~ /Continue/ ? @char.nextcreatestep() : 'show'), :id => @char
  end

  def open_header
    @char = Char.find(params[:id])
    h = Header.find(params[:header]);
    hcosts = @char.headercosts

    if @char.cp_avail < hcosts[h.id]
      return render :partial => "headers/closedpick", :locals => {:h => h, :char => @char, :hcosts => hcosts }
    end

    if h.hidden? && !session[:staff] && !Grant::find(:all, :conditions => "char_id = #{@char.id} and type = 'HeaderGrant' and correlated_id = #{h.id}")
      return render :layout => false, :text => "<b>Not allowed to open #{h.id}</b>"
    end

    if @char.hasresistmagic and h.category =~ /Magic/ and h.name !~ /Counter/
      return render :layout => false, :text => "<b>Cannot purchase #{h.name}: Character has Resist Magic and #{h.name} is a magic header</b>"
    end

    @char.open_header(h)

    @cskills = @char.skillhash
    @cheaders = @char.headers
    @sbyh = SkillHeader.skillsbyheader

    costs = @char.skillcosts

    if h.name == 'Sigils'
        render :partial => "headers/sigils", :locals => {:h => h, :cheaders => @cheaders, :sbyh => @sbyh, :cskills => @cskills, :cskillsleft => [], :costs => costs, :cid => params[:id], :char => @char}
    else
        render :partial => "headers/pick", :locals => {:h => h, :cheaders => @cheaders, :sbyh => @sbyh, :cskills => @cskills, :cskillsleft => [], :costs => costs, :char => @char}
    end

  end

  def remove_header
    h = Header.find(params[:header]);
    if session[:admin]
      @char = Char.find(params[:id])
      @char.remove_header(h)

      @hcosts = @char.headercosts

      #return a closed pick
      return render :partial => "headers/closedpick", :locals => {:h => h, :char => @char, :hcosts => @hcosts}
    end
  end
  
  def freesigil
    @char = Char.find(params[:id])
    h = Header.find(params[:header]);
    sk = Skill.find(params[:sid]);
    @cs = CharSkill.new(:char => @char, :skill => sk, :count => 1)
    @cs.save!
    @grant = Grant.new(:char_id => @char.id, :correlated_id => sk.id, :reason => "Free sigil of the spheres in Scrollcraft", :type => 'SkillGrant')
    @grant.save!
    @cskills = @char.skillhash
    @sbyh = SkillHeader.skillsbyheader
    costs = @char.skillcosts
    @cheaders = @char.headers
    render :partial => "headers/pick", :locals => {:h => h, :cheaders => @cheaders, :sbyh => @sbyh, :cskills => @cskills, :cskillsleft => [], :costs => costs}
  end

  def cpstats
    @char = Char.find(params[:id])
    render :partial => "cpstats", :locals => {:char => @char }
  end

  def destroy
    Char.find(params[:id]).destroy
    CharSkill.delete_all("char_id = #{params[:id]}")
    CharHeader.delete_all("char_id = #{params[:id]}")
    CharOrigin.delete_all("char_id = #{params[:id]}")
    CharLog.delete_all("char_id = #{params[:id]}")
    Grant.delete_all("char_id = #{params[:id]}")
    Bgs.delete_all("char_id = #{params[:id]}")
    EventMessage.delete_all("char_id = #{params[:id]}")
    redirect_to :action => 'list'
  end

  def toggle
    char = Char.find(params[:id])
    if session[:chars].include? char
      session[:chars].delete char
    else
      session[:chars].push(char)
    end
    render :partial => "chars/toggle", :locals => {:char => char}
  end

  def cleartoggle
    session[:chars] = []
    redirect_to :action => :list
  end

  def multitoggle
    filter = params[:filter] ? params[:filter] : 'all'
    
    if filter == 'pc'
      @chars = Char.find(:all, :conditions => "npc = 0")
    elsif filter == 'npc'
      @chars = Char.find(:all, :conditions => "npc = 1")
    elsif filter == 'attn'
      @chars = Char.find(:all, :conditions => "staff_attn = 1")
    elsif filter == 'name'
      @chars = Char.find(:all, :conditions => ["name like ?","%"+params[:filtervalue]+"%"])
    elsif filter == 'origin'
      @chars = Char.find_by_sql("select c.* from chars c, char_origins co where co.char_id = c.id and co.origin_id=#{params[:filtervalue].to_i} group by c.id")
    elsif filter == 'header'
      @chars = Char.find_by_sql("select c.* from chars c, char_headers ch where ch.char_id = c.id and ch.header_id=#{params[:filtervalue].to_i} group by c.id")
    elsif filter == 'skill'
      @chars = Char.find_by_sql("select c.* from chars c, char_skills cs, skills s where cs.char_id = c.id and cs.skill_id=s.id and s.name like '%#{Char.connection.quote_string(params[:filtervalue])}%' group by c.id")
    else
      @chars = Char.find(:all)
    end

    if params[:select]
      session[:chars] = (session[:chars] + @chars).uniq
    else
      session[:chars] = session[:chars] - @chars
    end
    redirect_to :action => :list, :filter => params[:filter], :filtervalue => params[:filtervalue], :page => params[:page]
  end


  def print
    _p = PDF::Writer.new :orientation => :landscape
    _p.select_font 'Times-Roman'
    _p.start_columns

    @char = Char.find(params[:id])
    @char.write_to_pdf(_p,params[:detail],0)
    
    send_data _p.render, :filename => @char.name+'.pdf', :type => "application/pdf"
  end

  def printselected
    _p = PDF::Writer.new :orientation => :landscape
    _p.select_font 'Times-Roman'
    _p.start_columns

    first = true

    for char in session[:chars]
      _p.start_new_page(true) if !first
      first = false
      char.write_to_pdf(_p,params[:detail],0)
    end

    send_data _p.render, :filename => 'chars.pdf', :type => "application/pdf"
  end

  def missingperm_redirect
    redirect_to :controller => "players", :action => "show", :id => session[:user]
    flash[:notice] = "Permissions not set up for that action"
  end

  def eperm_redirect
    redirect_to :controller => "players", :action => "show", :id => session[:user]
    flash[:notice] = "You don't have permission to perform that operation"
  end

  @@perms = { "index" => "staff_only", "list" => "staff_only",
    "show" => "staff_or_owns", "print" => "staff_or_owns",
    "brief" => "staff_or_owns", "pick" => "admin_or_owns",
    "dopick" => "admin_or_owns", "open_header" => "admin_or_owns", "remove_header" => "admin_or_owns",
    "printselected" => "staff_only", "toggle" => "staff_only",
    "cpstats" => "staff_or_owns", "freesigil" => "admin_or_owns",
    "destroy" => "admin_only", "new" => "any_user",
    "create" => "any_user", "edit" => "staff_or_owns", 
    "update" => "staff_or_owns", "getlog" => "staff_or_owns",
    "steal" => "admin_only", "cleartoggle" => "staff_only",
    "multitoggle" => "staff_only", "editdetails" => "admin_or_owns",
    "addrace" => "admin_or_owns", "addbackground" => "admin_or_owns",
    "doaddrace" => "admin_or_owns", "doaddbackground" => "admin_or_owns",
    "reset" => "admin_or_owns"}

  around_filter do |controller, action| 
    method = @@perms[controller.action_name]
    if controller.params[:id]
      obj = Char.find(controller.params[:id])
    else
      obj = nil
    end
    if method == nil
      controller.missingperm_redirect
    elsif ApplicationController.send(method,controller.session,obj)
      action.call
    else
      controller.eperm_redirect
    end
  end


end
