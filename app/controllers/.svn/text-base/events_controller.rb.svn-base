require 'pdf/writer'

class EventsController < ApplicationController
  def index
    list
    render :action => 'list'
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :action => :list }

  verify :session => :user, :except => [:index, :list, :show, :notes], :redirect_to => { :action => :list }, :add_flash => {:notice => "Must log in before interacting with events"}

  def list
    @future = Event.find(:all,:conditions => "date > now()",:order => "date asc")
    @past   = Event.find(:all,:conditions => "date < now()", :order => "date desc")
  end

  def show
    @event = Event.find(params[:id])
    if @event.date > Time.now()
      @ppls  = Registration.find(:all, :conditions => ["event_id = ?",params[:id]],
                                 :include => [{:player => :active_char}]).collect {|a| {:player => a.player, :char => a.player.active_char, :mealplan => a.mealplan, :cabin => a.cabin, :notes => a.notes, :regid => a.id}}
      @regs = {}
      @unreg = Array.new
    else
      @ppls = Attendance.find(:all,:conditions => ["event_id = ?",params[:id]],
                               :include => [:player,:char]).collect {|a| {:player => a.player, :char => a.char}}
      @regs = {}
      Registration.find(:all, :conditions => ["event_id = ?",params[:id]], :include => :player).each {|r| @regs[r.player_id] = r.player}
      @unreg = Array.new
    end
    @playerppls = @ppls.find_all {|r| r[:player].acl == 'Player'}
    @staffppls = @ppls.find_all {|r| r[:player].acl != 'Player'}
    @playerppls.sort! {|a,b| (a[:char] ? a[:char].name : "ZZZZ") <=> (b[:char] ? b[:char].name : "ZZZZ") }
    @staffppls.sort! {|a,b| (a[:char] ? a[:char].name : "ZZZZ") <=> (b[:char] ? b[:char].name : "ZZZZ") }
    @ppls = @playerppls+[nil]+@staffppls

    if session[:staff]
      if params[:print]
        _p = PDF::Writer.new
        #:orientation => :landscape
        _p.select_font 'Times-Roman'
        @event.write_to_pdf(_p,@playerppls,@staffppls)
        send_data _p.render, :filename => "Registration #{@event.name}.pdf", :type => "application/pdf"
      else
        render :action => :staffshow
      end
    end
  end
  
  def regedit
    @reg = Registration.find(params[:reg_id], :include => ["player","event"])
    @meals = Registration.find_by_sql("select mealplan,count(mealplan) as count from registrations group by mealplan order by count desc,mealplan").collect { |r| (not r.mealplan or r.mealplan.empty?) ? nil : r.mealplan }
    @meals.compact!
    @cabins = Registration.find_by_sql("select cabin,count(cabin) as count from registrations group by cabin order by count desc, cabin").collect { |r| (not r.cabin or r.cabin.empty?) ? nil : r.cabin }
    @cabins.compact!
  end

  def regsubmit
    @reg = Registration.find(params[:reg_id])
    @reg.mealplan = params[:mealplan] ? params[:mealplan] : params[:mealplannew]
    @reg.cabin = params[:cabin] ? params[:cabin] : params[:cabinnew]
    @reg.notes = params[:notes]
    @reg.save!
    
    flash[:notice] = 'Registration was successfully updated.'
    redirect_to :action => :show, :id => @reg.event
  end

  def notes
    render :partial => "events/notes", :locals => {:event => Event.find(params[:id])}
  end

  def summary
    render :partial => "events/summary", :locals => {:event => Event.find(params[:id])}
  end

  def skillscoming
    @event = Event.find(params[:id])
    skills = @event.skillscoming(params[:sort])
    render :partial => "events/skillscoming", :locals => {:event => @event, :skills => skills }
  end

  def skillscomingbychar
    @event = Event.find(params[:id])
    @skill = Skill.find(params[:skill_id])
    chars = @event.skillscomingbychar(@skill)
    render :partial => "events/skillscomingbychar", :locals => {:event => @event, :chars => chars, :counter => params[:counter] }
  end

  def printregisteredchars
    @event = Event.find(params[:id])

    _p = PDF::Writer.new :orientation => :landscape
    _p.select_font 'Times-Roman'
    _p.start_columns

    first = true

    for char in Char.find_by_sql("select c.* from chars c, players p, registrations r where r.player_id = p.id and p.active_char_id = c.id and r.event_id = #{@event.id} and p.acl='Player' order by c.name")
      _p.start_new_page(true) if !first
      first = false
      char.write_to_pdf(_p,params[:detail],@event.id)

    end

    send_data _p.render, :filename => "Chars-#{@event.name}.pdf", :type => "application/pdf"
  end

  def printregisteredchar
    @event = Event.find(params[:id])
    @char  = Char.find(params[:char_id])
    
    _p = PDF::Writer.new :orientation => :landscape
    _p.select_font 'Times-Roman'
    _p.start_columns

    @char.write_to_pdf(_p,params[:detail],@event.id)

    send_data _p.render, :filename => "#{@char.name}-#{@event.name}.pdf", :type => "application/pdf"
  end

  def new
    @event = Event.new
  end

  def create
    @event = Event.new(params[:event])
    if @event.save
      flash[:notice] = 'Event was successfully created.'
      redirect_to :action => 'list'
    else
      render :action => 'new'
    end
  end

  def edit
    @event = Event.find(params[:id])
  end

  def update
    @event = Event.find(params[:id])
    if @event.update_attributes(params[:event])
      flash[:notice] = 'Event was successfully updated.'
      redirect_to :action => 'show', :id => @event
    else
      render :action => 'edit'
    end
  end

  def destroy
    Event.find(params[:id]).destroy
    redirect_to :action => 'list'
  end

  def missingperm_redirect
    redirect_to :controller => "players", :action => "show", :id => session[:user]
    flash[:notice] = "Permissions not set up for that action"
  end

  def eperm_redirect
    redirect_to :controller => "players", :action => "show", :id => session[:user]
    flash[:notice] = "You don't have permission to perform that operation"
  end

  @@perms = {
    "destroy" => "admin_only", "new" => "admin_only",
    "create" => "admin_only", "edit" => "admin_only", 
    "update" => "admin_only", "summary" => "staff_only",
    "printregisteredchars" => "staff_only",
    "printregisteredchar" => "staff_only",
    "skillscoming" => "staff_only", "skillscomingbychar" => "staff_only",
    "staffshow" => "staff_only",
    "regedit" => "admin_only", "regsubmit" => "admin_only"
  }

  around_filter do |controller, action| 
    method = @@perms[controller.action_name]
    if controller.params[:id]
      obj = Event.find(controller.params[:id])
    else
      obj = nil
    end
    if method == nil
      action.call
    elsif ApplicationController.send(method,controller.session,obj)
      action.call
    else
      controller.eperm_redirect
    end
  end
end
