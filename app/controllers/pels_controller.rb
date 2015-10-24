class PelsController < ApplicationController
  def index
    list
    render :action => 'list'
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :action => :list }

  def list
    if params[:event_id]
      @event = Event.find(params[:event_id])
    else
      @event = Event.last
    end
    @cond = ["pels.event_id = ?",@event]
    if params[:searchstring]
      @cond[0] = @cond[0] + " and (pels.likes like ? or pels.dislikes like ? or pels.bestmoments like ? or pels.worstmoments like ? or pels.learned like ? or pels.data like ?)"
      @cond.push "%#{params[:searchstring]}%"
      @cond.push "%#{params[:searchstring]}%"
      @cond.push "%#{params[:searchstring]}%"
      @cond.push "%#{params[:searchstring]}%"
      @cond.push "%#{params[:searchstring]}%"
      @cond.push "%#{params[:searchstring]}%"
    end
    orderbymap = {"pname" => "players.name","npc" => "players.acl,players.name","time" => "pels.submit_date desc,players.name", "rating" => "pels.rating,pels.submit_date,players.name"}
    orderby = orderbymap[(params[:orderby] ? params[:orderby] : "time")]
    
    @pels = Pel.find(:all, :include => [:player], :conditions => @cond, :order => orderby)
    @attend = {}
    Attendance.find(:all, :conditions => {:event_id => @event.id}).each {|a| @attend[a.player_id]=a}
    @peld = {}
    PelComment.find_by_sql("select p1.pel_id,p1.player_id,p.name,p1.comment,p1.submit_date,p2.count from pel_comments p1 join (select pel_id,count(*) as count,max(submit_date) as submit_date from pel_comments group by pel_id) as p2 on p1.pel_id = p2.pel_id and p1.submit_date = p2.submit_date join players p on p.id = p1.player_id").each {|t| @peld[t.pel_id]={:count => t.count, :comment => t.comment, :date => t.submit_date, :id => t.player_id, :name => t.name}}
  end

  def comments
    @pel = Pel.find(params[:id])
    @pelcomments = PelComment.find(:all,:conditions => {:pel_id => @pel.id }, :order => "submit_date", :include => :player)
    @addcomment = params[:addcomment]
    render :partial => "pels/comments", :locals => {:pel => @pel, :comments => @pelcomments, :addcomment => @addcomment, :searchstring => params[:searchstring] }
  end

  def postcomment
    @pel = Pel.find(params[:id])
    PelComment.new(:pel_id => @pel.id, :player_id => session[:user].id, :comment => params[:comment], :submit_date => Time.new).save!
    @pelcomments = PelComment.find(:all,:conditions => {:pel_id => @pel.id }, :order => "submit_date", :include => :player)
    render :partial => "pels/comments", :locals => {:pel => @pel, :comments => @pelcomments, :addcomment => nil }
  end    

  def deletecomment
    @pel = Pel.find(params[:id])
    PelComment.find(params[:commentid]).destroy
    @pelcomments = PelComment.find(:all,:conditions => {:pel_id => @pel.id }, :order => "submit_date", :include => :player)
    render :partial => "pels/comments", :locals => {:pel => @pel, :comments => @pelcomments, :addcomment => nil }
  end
    
  def show
    @pel = Pel.find(params[:id], :include => [:player,:event])
    @attend = Attendance.find(:first,:conditions => {:event_id => @pel.event_id, :player_id => @pel.player_id})
  end

  def showshort
    @pel = Pel.find(params[:id], :include => [:player,:event])
    @attend = Attendance.find(:first,:conditions => {:event_id => @pel.event_id, :player_id => @pel.player_id})
    @comments = PelComment.find(:all,:conditions => {:pel_id => @pel.id }, :order => "submit_date", :include => :player)
    render :partial => "pels/showshort", :locals => {:pel => @pel, :attend => @attend}
  end

  def showrest
    @pel = Pel.find(params[:id], :include => [:player,:event])
    render :partial => "pels/showrest", :locals => {:pel => @pel}
  end

  def new
    @pel = Pel.new
    if session[:admin]
      @player = Player.find(params[:player_id])
    else
      @player = session[:user]
    end
    @event = Event.find(params[:event_id])
    if Time.new < @event.date
      flash[:notice] = "Cannot enter pel before the event has happened!"
      redirect_to :action => :show, :controller => :players, :id => session[:user].id
    end
    @pel.event_id = @event.id
    @pel.player_id = @player.id
    @pelcheck = Pel.find(:first, :conditions => {:player_id => @pel.player_id, :event_id => @pel.event_id })
    if @pelcheck
      flash[:notice] = "Cannot enter more than one pel!"
      redirect_to :action => :show, :controller => :players, :id => session[:user].id
    end
    @attend = Attendance.find(:first, :conditions => {:player_id => @player.id, :event_id => @event.id }, :include => :char)
    if @attend
      @char = @attend.char
    else
      @char = @player.active_char
    end
  end

  def create
    @pel = Pel.new(params[:pel])
    @pel.player_id = session[:user].id unless session[:admin]
    if @pel.overallSize < Pel.minSize and not session[:admin]
      flash[:notice] = "Pel too small (minimum #{Pel.minSize} characters); we know you can do better than that!"
      @player = @pel.player
      @event = @pel.event
      @attend = Attendance.find(:first, :conditions => {:player_id => @player.id, :event_id => @event.id }, :include => :char)
      if @attend
        @char = @attend.char
      else
        @char = @player.active_char
      end
      
      render :action => :new
      return
    end
    @pel.submit_date = Time.new
    @event = Event.find(@pel.event_id)
    @player = @pel.player
    if @pel.submit_date < @event.date
      flash[:notice] = "Cannot enter pel before the event has happened!"
      redirect_to :action => :show, :controller => :players, :id => session[:user].id
    end
    @pelcheck = Pel.find(:first, :conditions => {:player_id => @pel.player_id, :event_id => @pel.event_id })
    if @pelcheck
      flash[:notice] = "Cannot enter more than one pel!"
      redirect_to :action => :show, :controller => :players, :id => session[:user].id
    end
    if @event.pel_by > @pel.submit_date
      @pel.transaction do
        @attend = Attendance.find(:first, :conditions => {:player_id => @pel.player_id, :event_id => @pel.event_id}, :lock => true)
        if @attend
          @player.cp_avail = @player.cp_avail + 1;
          @player.save!
          PlayerLog.new(:player_id => @player.id, :entry => "+1 CP for PEL for #{@event.name}").save!
          flash[:notice] = "PEL submitted before deadline and you've been marked attended: +1 CP"
        else
          flash[:notice] = "PEL submitted before deadline, but you haven't been marked attended.  You'll be awarded your CP for PEL when you are so marked."
        end
        @pel.save!
      end
    else
      @pel.save
      flash[:notice] = 'Pel submitted after deadline; no CP but (potentially) plot!'
    end
    redirect_to :action => :show, :controller => :players, :id => @pel.player_id
  end

  def edit
    @pel = Pel.find(params[:id], :include => [:player,:event])
    @attend = Attendance.find(:first, :conditions => {:player_id => @pel.player_id, :event_id => @pel.event_id })
  end

  def update    
    @pel = Pel.find(params[:id])
    params[:pel].delete('event_id')
    params[:pel].delete('player_id')    
    params[:pel].delete('submit_date')    
    if @pel.overallSize < Pel.minSize and not session[:admin]
      flash[:notice] = "Pel too small (minimum #{Pel.minSize} characters); we know you can do better than that!"
      @player = @pel.player
      @event = @pel.event
      @attend = Attendance.find(:first, :conditions => {:player_id => @player.id, :event_id => @event.id })
      if @attend
        @char = Char.find(@attend.char_id)
      else
        @char = @player.active_char
      end
      
      render :action => :new
      return
    end
    @pel.submit_date = Time.new
    @pel.update_attributes!(params[:pel])
    flash[:notice] = "Pel was successfully updated."
    redirect_to :action => 'show', :id => @pel
  end

  def destroy
    @pel = Pel.find(params[:id])
    @pel.destroy
    redirect_to :action => 'show', :controller => :players, :id => @pel.player_id
  end

  def missingperm_redirect
    flash[:notice] = "Permissions not set up for that action"
    redirect_to :controller => "players", :action => "show", :id => session[:user]
  end

  def eperm_redirect
    flash[:notice] = "You don't have permission to perform that operation"
    redirect_to :controller => "players", :action => "show", :id => session[:user]
  end

  @@perms = {"new" => "any_user", "create" => "any_user", 
    "show" => "staff_or_owns", "list" => "staff_only", 
    "edit" => "admin_or_owns", "update" => "admin_or_owns", 
    "destroy" => "admin_or_owns", "comments" => "staff_only",
    "postcomment" => "staff_only", "deletecomment" => "staff_only",
    "showshort" => "staff_only", "showrest" => "staff_only"}

  around_filter do |controller, action| 
    method = @@perms[controller.action_name]
    if controller.params[:id]
      obj = Pel.find(controller.params[:id])
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


