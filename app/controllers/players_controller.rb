require 'digest/md5'

class PlayersController < ApplicationController
  def index
    list
    render :action => 'list'
  end

  def welcome
    @event = Event.next()
    if session[:user]
      if @event
        @reg = Registration.where(event_id: @event.id, player_id: session[:user][:id]).first()
      end
      @last = Event.last()
      @attend = Attendance.where(event_id: @last.id, player_id: session[:user][:id]).includes(:char).first()
      if @attend
        @pel = Pel.where(event_id: @last.id, player_id: session[:user][:id]).first()
      end
    end
  end

  def login
    if session[:user]
      redirect_to :action => :show, :id => session[:user].id
    end
  end

  def dologin
    nu = Nukeuser.where(['username = ? and user_password=md5(?)',params[:username],params[:password]]).first()

    if nu
      flash[:notice] = ''
      @player = Player.where(username: nu.username).first()

      logger.info("player")
      logger.info(@player)
      if not @player
        @player = Player.grab(nu)
        flash[:notice] = "Created local Player for '#{@player.name}' with information from main ToV site<br>"
      end
      session[:user] = @player
      session[:staff] = true if @player.staff?
      session[:admin] = true if @player.admin?
      session[:avail] = @player.viewable(nil)
      redirect_to :action => :show, :id => @player[:id]
    else
      flash[:notice] = "Username or password incorrect"
      redirect_to :action => :login
    end
  end

  def logout
    session[:user] = nil
    session[:staff] = nil
    session[:admin] = nil
    session[:avail] = nil
    redirect_to :controller => :players, :action => :welcome
  end

  def harvest
    if params[:type] == "all"
      @nus = Nukeuser.find(:all)
    elsif params[:type] == "username"
      @nus = Nukeuser.find(:all, :conditions => ['username like ?',"%"+params[:term]+"%"])
    elsif params[:type] == "email"
      @nus = Nukeuser.find(:all, :conditions => ['user_email like ?',"%"+params[:term]+"%"])
    elsif params[:type] == "name"
      @nus = Nukeuser.find(:all, :conditions => ['name like ?',"%"+params[:term]+"%"])
    else
      @nus = []
    end
  end

  def grab
    nu = Nukeuser.find(:first, :conditions => ["username = ?",params[:username]])
    if nu
      p = Player.grab(nu)
      redirect_to :action => :show, :id => p.id
    else
      redirect_to :action => :harvest
    end
  end

  def list
    if !session[:players]
      session[:players] = Array.new
    end
    filter = params[:filter] ? params[:filter] : 'all'
    @nextevent = Event.next()
    @lastevent = Event.last()
    if filter == 'acl'
      @title = params[:filtervalue]
      if params[:filtervalue] == 'Staff'
        @player_pages, @players = paginate :players, :per_page => 30, :order => "players.name", :conditions => "players.acl != 'Player'", :include => :active_char
      else
        @player_pages, @players = paginate :players, :per_page => 30, :order => "players.name", :conditions => ['players.acl = ?',params[:filtervalue]], :include => :active_char
      end
    elsif filter == 'name'
      @title = "Name like #{params[:filtervalue]}"
      @player_pages, @players = paginate :players, :per_page => 30, :order => "players.name", :conditions => ["players.name like ?","%"+params[:filtervalue]+"%"], :include => :active_char
      if @players.size == 1
        redirect_to :action => :show, :id => @players[0].id
      end
    elsif filter == 'registered'
      o = Event.find(params[:filtervalue])
      @title = "Registered for Event #{o ? o.name : '???'}"
      sql = "select p.* from players p, registrations r where r.player_id = p.id and r.event_id=#{params[:filtervalue].to_i} group by p.id"
      @player_pages, @players = paginate_by_sql Player, sql, 30
    elsif filter == 'attended'
      o = Event.find(params[:filtervalue])
      @title = "Attended Event #{o ? o.name : '???'}"
      sql = "select p.* from players p, attendances a where a.player_id = p.id and a.event_id=#{params[:filtervalue].to_i} group by p.id"
      @player_pages, @players = paginate_by_sql Player, sql, 30
    elsif filter == 'selected'
      @title = "Selected"
      @player_pages = Paginator.new self, session[:players].size, 30, params[:page]
      @players = session[:players][@player_pages.current.offset,
                              (@player_pages.current.offset+@player_pages.items_per_page > session[:players].size ?
                               session[:players].size - @player_pages.current.offset :
                               @player_pages.items_per_page)]
    else
      @title = "All Players"
      @player_pages, @players = paginate :players, :per_page => 30, :order => "players.name", :include => :active_char
    end
    @tags = PlayerTag.allTags()
  end

  def show

    logger.info("I'm showing the player")
    if !session[:players]
      session[:players] = Array.new
    end
    @player = Player.find(params[:id])
    @futureevents = Event.where("date > now()").order("date")
    @pastevents = Event.where("date < now()").order("date desc")
    @regs = {}
    Registration.where("player_id = ?",@player.id).each {|r| @regs[r.event_id] = r }
    @atts = {}
    Attendance.where("attendances.player_id = ?",@player.id).includes(:char).each {|a| @atts[a.event_id] = a }
    @pels = {}
    Pel.where("pels.player_id = ?",@player.id).includes(:event).each {|a| @pels[a.event_id] = a }
    @logs = PlayerLog.where("player_id=?",@player.id).order("ts desc").limit(3)
  end

  def getlog
    logs = PlayerLog.find(:all, :limit => 100, :offset => 3, :order => "ts desc", :conditions =>  ["player_id=?",params[:id]])
    render :partial => "log", :locals => {:logs => logs, :start => false}
  end

  def new
    @player = Player.new
  end

  def create
    redirect_to :action => :welcome
    return
    # @player = Player.new(params[:player])
    # @player.cp_avail = 0 unless session[:user] && session[:user].staff?
    # @player.acl = 'Player' unless session[:user] && session[:user].admin?
    #if @player.save
    #  flash[:notice] = 'Player was successfully created.'
    #  session[:user] = @player unless session[:user]
    #  redirect_to :action => 'show', :id => @player
    #else
    #  render :action => 'new'
    #end
  end

  def edit
    @player = Player.find(params[:id])
  end

  def update
    @player = Player.find(params[:id])
    params[:player].delete('cp_avail') unless session[:staff]
    params[:player].delete('game_started') unless session[:staff]
    params[:player].delete('acl') unless session[:admin]
    params[:player].delete('id')
    params[:player].delete('username')
    params[:player].delete('active_char_id')
    if @player.update_attributes(params[:player])
      flash[:notice] = 'Player was successfully updated.'
      redirect_to :action => 'show', :id => @player
    else
      render :action => 'edit'
    end
  end

  def setactive
    @player = Player.find(params[:id])
    if not session[:admin] and not @player.id == session[:user].id
      eperm_redirect
    else
      @char = Char.find(params[:charid])
      @player.setactive(@char.id,session)
      redirect_to :action => 'show', :id => @player
    end
  end

  def register
    if not session[:admin] and params[:reg][:player_id].to_i != session[:user].id
      flash[:notice] = "Staff may only register themselves."
    elsif Registration.find(:first, :conditions => { :player_id => params[:reg][:player_id],
                           :event_id => params[:reg][:event_id]})
      flash[:notice] = "Already registered"
    else
      @reg = Registration.new(params[:reg])
      @reg.save!
      flash[:notice] = "Registered #{@reg.player.name} for #{@reg.event.name}"
    end
    redirect_to :action => 'show', :id => params[:reg][:player_id]
  end

  def unregister
    reg = Registration.find(params[:registration_id])
    player = reg.player
    event = reg.event
    reg.destroy
    flash[:notice] = "Unregistered #{player.name} from #{event.name}"
    redirect_to :action => 'show', :id => player.id
  end

  def unattend
    att = Attendance.find(params[:attendance_id],:include => [:player,:event])
    player = att.player
    event = att.event
    att.destroy
    pel = Pel.find(:first,:conditions => {:event_id => event.id, :player_id => player.id})
    if pel
      player.cp_avail = player.cp_avail - 4
      flash[:notice] = "Marked #{player.name} as not attending #{event.name} and removed 4 CPs (withdrawn CP for PEL as well)"
    else
      player.cp_avail = player.cp_avail - 3
      flash[:notice] = "Marked #{player.name} as not attending #{event.name} and removed 3 CPs"
    end
    player.save!
    PlayerLog.new(:player_id => player.id, :entry => flash[:notice]).save!
    redirect_to :action => :show, :id => player.id
  end

  def bulkgrantcps
    if !session[:players]
      session[:players] = Array.new
    end
    @players = session[:players]
  end

  def bulkregister
    if !session[:players]
      session[:players] = Array.new
    end
    @event = Event.find(params[:event_id])
    flash[:notice] = "Registered for #{@event.name}:<br>"

    for player in Player.find(session[:players].collect {|p| p.id})
      if player.active_char_id
        @reg = Registration.new(:player_id => player.id, :event_id => @event.id)
        flash[:notice] += player.name+" <br>"
      else
        @reg = Registration.new(:player_id => player.id, :event_id => @event.id)
        flash[:notice] += player.name+" (no character)<br>"
      end
      @reg.save!
      PlayerLog.new(:player_id => player.id, :entry => "Registered for #{@event.name}").save!
    end
    redirect_to :action => :list
  end

  def bulkattended
    if !session[:players]
      session[:players] = Array.new
    end
    @event = Event.find(params[:event_id])
    flash[:notice] = "Attended #{@event.name}:<br>"
    @atts = {}
    Attendance.find(:all, :conditions => ["event_id = ?", @event.id]).each {|a| @atts[a.player_id] = a}

    for player in Player.find(session[:players].collect {|p| p.id})
      if @atts[player.id]
        flash[:notice] += player.name+" already marked attended<br>"
      else
        if player.active_char_id
          @att = Attendance.new(:player_id => player.id, :event_id => @event.id, :char_id => player.active_char_id)
          flash[:notice] += player.name+" <br>"
        else
          @att = Attendance.new(:player_id => player.id, :event_id => @event.id)
          flash[:notice] += player.name+" (no character)<br>"
        end
        @att.save!
        @atts[player.id] = @att
        player.cp_avail = player.cp_avail + 3
        PlayerLog.new(:player_id => player.id, :entry => "+3 CP for attending #{@event.name}").save!
        pel = Pel.find(:first,:conditions => {:player_id => player.id, :event_id => @event.id})
        if pel
          player.cp_avail = player.cp_avail + 1
          PlayerLog.new(:player_id => player.id, :entry => "+1 CP for PEL for #{@event.name}").save!
        end
        player.save!
      end
    end
    redirect_to :action => :list
  end

  def bulkemail
    if !session[:players]
      session[:players] = Array.new
    end
    emails = session[:players].collect {|p| p.email }
    render :layout => false, :text => emails.join(",")
  end

  def grantcps
    amt = params[:amount].to_i
    if amt <= 0
      flash[:notice] = "Invalid CP grant amount: "+params[:amount]
    else
      notice = "#{session[:user].name} granted #{amt} cps: #{params[:reason]}"
      for player in session[:players]
        player.cp_avail += amt
        player.save!
        pl = PlayerLog.new(:player_id => player.id, :entry => notice)
        pl.save!
      end
      flash[:notice] = "Granted #{amt} cp(s) for #{params[:reason]} to "+(session[:players].collect {|p| p.name+" - "}).to_s
    end
    redirect_to :action => :list
  end

  def xfercps
    @player = Player.find(params[:id])
    @char = Char.find(params[:charid])
    amt = params[:points].to_i
    amt = @char.pointcap if @char.pointcap < amt
    amt = @player.cp_avail if @player.cp_avail < amt
    if amt > 0
      @player.cp_avail = @player.cp_avail - amt
      @char.cp_avail = @char.cp_avail + amt
      @char.cp_transferred = @char.cp_transferred + amt
      Player.transaction do
        @player.save!
        @char.save!
        flash[:notice] = "Transferred "+amt.to_s+" CPs from "+@player.name+" to "+@char.name+"."
        cl = CharLog.new(:char => @char, :entry => flash[:notice])
        cl.save!
        pl = PlayerLog.new(:player => @player, :entry => flash[:notice])
        pl.save!
      end
    else
      flash[:notice] = "No CPs Transferred; either you're out of CPs or you hit the point cap."
    end
    redirect_to :action => 'show', :id => @player.id
  end

  def destroy
    Player.find(params[:id]).destroy
    redirect_to :action => 'list'
  end

  def toggle
    player = Player.find(params[:id])
    if session[:players].include? player
      session[:players].delete player
    else
      session[:players].push(player)
    end
    render :partial => "players/toggle", :locals => {:player => player}
  end

  def cleartoggle
    session[:players] = []
    redirect_to :action => :list
  end

  def multitoggle
    filter = params[:filter] ? params[:filter] : 'all'

    if filter == 'name'
      @players = Player.find(:all, :conditions => ["name like ?","%"+params[:filtervalue]+"%"])
    elsif filter == 'acl'
      if params[:filtervalue] == 'Staff'
        @players = Player.find(:all, :conditions => "acl != 'Player'")
      else
        @players = Player.find(:all, :conditions => ["acl = ?",params[:filtervalue]])
      end
    elsif filter == 'registered'
      @players = Player.find_by_sql("select p.* from players p, registrations r where r.player_id = p.id and r.event_id=#{params[:filtervalue].to_i} group by p.id")
    elsif filter == 'attended'
      @players = Player.find_by_sql("select p.* from players p, attendances a where a.player_id = p.id and a.event_id=#{params[:filtervalue].to_i} group by p.id")
    else
      @players = Player.find(:all)
    end

    if params[:select]
      session[:players] = (session[:players] + @players).uniq
    else
      session[:players] = session[:players] - @players
    end
    redirect_to :action => :list, :filter => params[:filter], :filtervalue => params[:filtervalue], :page => params[:page]
  end

  def reset
    reset_session

    redirect_to "/"
  end

  def resetpointcap
    Char.resetpointcap(session[:user])
    flash[:notice] = "Point Cap Reset"
    redirect_to :action => 'adminconsole'
  end

  def droppriv
    if params[:level] == "staff"
      session[:admin] = nil
    elsif params[:level] == "player"
      session[:admin] = nil
      session[:staff] = nil
      session[:avail] = session[:user].viewable(false)
    end
    redirect_to :action => :welcome
  end

  def togglewide
    if session[:thin]
      session[:thin] = false
    else
      session[:thin] = true
    end
    render :text => "Success"
  end

  def missingperm_redirect
    flash[:notice] = "Permissions not set up for that action"
    redirect_to :controller => "players", :action => "show", :id => session[:user]["id"]
  end

  def eperm_redirect
    logger.info(session[:user])
    flash[:notice] = "You don't have permission to perform that operation"
    redirect_to :controller => "players", :action => "show", :id => session[:user]["id"]
  end

  @@perms = {"welcome" => "everyone", "new" => "everyone", "create" => "everyone",
    "login" => "everyone", "dologin" => "everyone", "logout" => "everyone",
    "show" => "staff_or_owns", "list" => "staff_only", "register" => "staff_only",
    "edit" => "admin_or_owns", "harvest" => "admin_only", "grab" => "admin_only",
    "update" => "admin_or_owns", "destroy" => "admin_only", "reset" => "everyone",
    "index" => "staff_only", "setactive" => "staff_only", "unregister" => "admin_only",
    "xfercps" => "admin_or_owns", "adminconsole" => "admin_only",
    "resetpointcap" => "admin_only", "toggle" => "staff_only",
    "cleartoggle" => "staff_only", "multitoggle" => "staff_only",
    "bulkgrantcps" => "admin_only", "grantcps" => "admin_only", 
    "bulkregister" => "admin_only", "getlog" => "staff_or_owns", 
    "droppriv" => "admin_only", "bulkemail" => "staff_only",
    "bulkattended" => "admin_only", "unattend" => "admin_only",
    "togglewide" => "everyone"}

  around_filter do |controller, action| 

    method = @@perms[controller.action_name]
    logger.info(method)
    if controller.params[:id]
      obj = Player.find(controller.params[:id])
      logger.info("around filter player find")
      logger.info(obj)
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

