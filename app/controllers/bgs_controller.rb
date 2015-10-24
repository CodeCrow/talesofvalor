class BgsController < ApplicationController
  def index
    list
    render :action => 'list'
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update, :submitanswer ],
         :redirect_to => { :action => :fulllist }

  def show
    @bgs = Bgs.find(params[:id], :include => [:char,:skill,:event])
    @bgscomments = BgsComment.find(:all,:conditions => {:bgs_id => @bgs.id }, :order => "submit_date", :include => :player)
  end

  def list
    @char = Char.find(params[:char_id])
    @event = Event.find(params[:event_id])
    @player = @char.player
    @bgsopenskills = Skill.find_by_sql("select s.* from skills s, skill_headers sh, headers h where s.id = sh.skill_id and s.bgs = 1 and (sh.header_id = 0 or (sh.header_id = h.id and h.hidden = 0)) group by s.id");
    @bgscount = @char.bgs_counts(@event.id)
    @bgsopen = ((@event.bgs_p and @event.bgs_by > Time.new) or session[:staff])
    @bgs = {}
    Bgs.find(:all, :conditions => ["event_id = ? and char_id = ?",params[:event_id],params[:char_id]], :include => :skill).each {|x| @bgs.has_key?(x.skill_id) ? @bgs[x.skill_id].push(x) : @bgs[x.skill_id] = [x] }
    @lastchar = nil
  end

  def eventlist
    if params[:event_id]
      @event = Event.find(params[:event_id])
    else
      @event = Event.next
      if not @event
        @event = Event.last
      end
      if not @event
        flash[:notice] = "No events yet; create one before viewing BGS."
        redirect_to :controller => :events, :action => :list
        return
      end
    end
    @cond = ["event_id = ?", @event.id]
    @assigned = params[:assigned]
    if @assigned and @assigned != "Any"
      if @assigned == "NULL"
        @cond[0] = @cond[0] + " and answering_player_id is null"
      else
        @cond[0] = @cond[0] + " and answering_player_id = ?"
        @cond.push params[:assigned]
      end
    end
    @search = params[:searchstring]
    if @search and not @search.empty?
      @cond[0] = @cond[0] + " and (chars.name like ? or players.name like ? or question like ? or answer like ?)"
      @cond.push "%#{params[:searchstring]}%"
      @cond.push "%#{params[:searchstring]}%"
      @cond.push "%#{params[:searchstring]}%"
      @cond.push "%#{params[:searchstring]}%"
    else
      @search = false
    end
    @skill = params[:skill]
    if @skill and @skill != "Any"
      @cond[0] = @cond[0] + " and bgs.skill_id = ?"
      @cond.push @skill
    end
    @answered = params[:answered]
    if @answered == "Yes"
      @cond[0] = @cond[0] + " and bgs.answer is not null and length(bgs.answer) > 0"
    elsif @answered == "No"
      @cond[0] = @cond[0] + " and (bgs.answer is null or length(bgs.answer) = 0)"
    end
    @filterstaff = params[:filterstaff]
    if @filterstaff == "1"
      @cond[0] = @cond[0] + " and not chars.npc"
    else
      @filterstaff = false
    end
    @bgss = Bgs.find(:all, :conditions => @cond, :include => {:char => :player,:skill => {}}, :order => "chars.name,char_id,skill_id,count desc")
    @regs = {}
    Registration.find(:all, :conditions => ["event_id = ?",@event.id]).each {|r| @regs[r.player_id] = r }
    @bgsd = {}
    BgsComment.find_by_sql("select b1.bgs_id,b1.player_id,p.name,b1.comment,b1.submit_date,b2.count from bgs_comments b1 join (select bgs_id,count(*) as count,max(submit_date) as submit_date from bgs_comments group by bgs_id) as b2 on b1.bgs_id = b2.bgs_id and b1.submit_date = b2.submit_date join players p on p.id = b1.player_id").each {|t| @bgsd[t.bgs_id]={:count => t.count, :comment => t.comment, :date => t.submit_date, :id => t.player_id, :name => t.name}}
    @assignees = Bgs.find_by_sql("select p.name,p.id from players p, bgs b where p.id = b.answering_player_id and b.event_id = #{@event.id} and p.id != #{session[:user].id} group by p.id order by p.name").collect {|p| [p.name,p.id]}
    @assignees = [["Select Staffer", "Any"],[session[:user].name,session[:user].id],["Unassigned","NULL"]].concat(@assignees)
    @skills = Skill.find(:all,:conditions => "bgs",:order => :name).collect {|s| [s.name,s.id]}
    @skills = [["Any","Any"]].concat @skills
    @answers = ["Either","Yes","No"]

    if params[:print]
      _p = PDF::Writer.new :orientation => :landscape
      _p.select_font 'Times-Roman'

      _p.text "BGS for #{@event.name}", :font_size => 24, :justification => :center

      for bgs in @bgss
        _p.text "#{bgs.char.name} (#{bgs.char.player.name}) #{bgs.skill.name} [#{bgs.count}]", :font_size => 18, :justification => :left
        
        if bgs.answering_player
          _p.text "Assigned to #{bgs.answering_player.name}", :font_size => 18
        end
        bgs.write_to_pdf(_p)
      end
    
      send_data _p.render, :filename => "BGS-#{@event.name}.pdf", :type => "application/pdf"
    end
  
  end

  def expand
    @bgs = Bgs.find(params[:id])
    @answerbox = params[:answerbox]
    @assignto = params[:assignto]
    @search = params[:search]
    if @assignto
      @options = Player.find(:all, :conditions => "acl != 'Player'", :order => "name").collect {|p| [p.name,p.id]}
    end
    render :partial => "bgs/expand", :locals => {:bgs => @bgs, :answerbox => @answerbox, :assignto => @assignto, :options => @options, :searchstring => @search }
  end

  def comments
    @bgs = Bgs.find(params[:id])
    @bgscomments = BgsComment.find(:all,:conditions => {:bgs_id => @bgs.id }, :order => "submit_date", :include => :player)
    @addcomment = params[:addcomment]
    render :partial => "bgs/comments", :locals => {:bgs => @bgs, :comments => @bgscomments, :addcomment => @addcomment, :searchstring => params[:searchstring] }
  end

  def postcomment
    @bgs = Bgs.find(params[:id])
    @addcomment = params[:addcomment]
    BgsComment.new(:bgs_id => @bgs.id, :player_id => session[:user].id, :comment => params[:comment], :submit_date => Time.new).save!
    @bgscomments = BgsComment.find(:all,:conditions => {:bgs_id => @bgs.id }, :order => "submit_date", :include => :player)
    render :partial => "bgs/comments", :locals => {:bgs => @bgs, :comments => @bgscomments, :addcomment => true }
  end    

  def deletecomment
    @bgs = Bgs.find(params[:id])
    BgsComment.find(params[:commentid]).destroy
    @bgscomments = BgsComment.find(:all,:conditions => {:bgs_id => @bgs.id }, :order => "submit_date", :include => :player)
    render :partial => "bgs/comments", :locals => {:bgs => @bgs, :comments => @bgscomments }
  end
    
  def submitanswer
    @bgs = Bgs.find(params[:id])
    @bgs.answer = params[:answer]
    @bgs.answer_date = Time.new
    @bgs.save!
    render :partial => "bgs/expand", :locals => { :bgs => @bgs, :answerbox => false, :assignto => false}
  end

  def assignto
    @bgs = Bgs.find(params[:id])
    @bgs.answering_player_id = params[:answering_player]
    @bgs.save!
    render :partial => "bgs/expand", :locals => { :bgs => @bgs, :answerbox => false, :assignto => false}
  end

  def assignee
    @bgs = Bgs.find(params[:id])
    render :partial => "bgs/assignee", :locals => { :player => @bgs.answering_player }
  end

  def new
    @char = Char.find(params[:char_id])
    @event = Event.find(params[:event_id])
    @skill = Skill.find(params[:skill_id])
    @bgscounts = @char.bgs_counts(@event.id)
    if not @skill.bgs
      flash[:notice] = "#{@skill.name} is not a between game skill"
      redirect_to :controller => :players, :action => :show, :id => session[:user].id
    else
      @bgs = Bgs.new(:char_id => @char.id, :event_id => @event.id, :skill_id => @skill.id)
    end
  end

  def create
    @bgs = Bgs.new(params[:bgs])
    if session[:staff]
      @bgs.answering_player_id = session[:user].id
      @bgs.answer_date = Time.new
    else
      @bgs.answer = ""
    end
    @event = @bgs.event
    @bgscount = @bgs.char.bgs_counts(@bgs.event_id)
    @avail = @bgscount[@bgs.skill_id] ? (@bgscount[@bgs.skill_id][1]-@bgscount[@bgs.skill_id][0]) : 0
    if @bgs.count < 0 or @bgs.count > @avail
      flash[:notice] = "Count exceeds available skills."
      redirect_to :action => :list, :event_id => @bgs.event_id, :char_id => @bgs.char_id
    elsif not @event.bgs_p and not session[:staff]
      flash[:notice] = "BGS not allowed for #{@event.name}"
      redirect_to :action => :list, :event_id => @bgs.event_id, :char_id => @bgs.char_id
    elsif Time.new > @event.bgs_by and not session[:staff]
      flash[:notice] = "Past time by which BGS must be submitted #{@event.bgs_by.strftime("%d %b %Y")}"
      redirect_to :action => :list, :event_id => @bgs.event_id, :char_id => @bgs.char_id
    elsif (session[:staff] or @bgs.char.player == session[:user]) and @bgs.skill.bgs?
      @bgs.submit_date = Time.new
      @tag = SkillTag.find(:first,:conditions => {:foreign_id => @bgs.skill.id} )
      if @tag
        @tagdesc = TagDescription.find(@tag.tag)
        @bgs.answering_player_id = @tagdesc.owner_id
      end
      if @bgs.save
        flash[:notice] = 'Bgs was successfully created.'
        redirect_to :action => 'list', :char_id => @bgs.char_id, :event_id => @bgs.event_id
      else
        render :action => 'new', :char_id => @char.id, :event_id => @event.id, :skill_id => @skill.id
      end
    else
      flash[:notice] = "Invalid skill (#{@bgs.skill.name}) or not owner of char"
      redirect_to :controller => :players, :action => :show, :id => session[:user]
    end
  end

  def edit
    @bgs = Bgs.find(params[:id], :include => [:event,:char,:skill])
    @char = @bgs.char
    @event = @bgs.event
    @skill = @bgs.skill
    @bgscounts = @char.bgs_counts(@event.id)
  end

  def update
    @bgs = Bgs.find(params[:id])
    params[:bgs].delete(:char_id)
    params[:bgs].delete(:event_id)
    params[:bgs].delete(:skill_id)
    @event = @bgs.event
    @bgscount = @bgs.char.bgs_counts(@bgs.event.id)
    newcount = params[:bgs][:count].to_i
    @avail = @bgscount[@bgs.skill_id] ? (@bgscount[@bgs.skill_id][1]-@bgscount[@bgs.skill_id][0]+@bgs.count) : 0
    if newcount < 0 or newcount > @avail
      flash[:notice] = "Count exceeds available skills."
      redirect_to :action => :list, :event_id => @bgs.event_id, :char_id => @bgs.char_id
    elsif Time.new > @event.bgs_by and not session[:staff]
      flash[:notice] = "Past time by which BGS must be submitted #{@event.bgs_by.strftime("%d %b %Y")}"
      redirect_to :action => :list, :event_id => @bgs.event_id, :char_id => @bgs.char_id
    elsif @bgs.update_attributes(params[:bgs])
      flash[:notice] = 'Bgs was successfully updated.'
      redirect_to :action => 'list', :event_id => @bgs.event_id, :char_id => @bgs.char_id
    else
      render :action => 'edit'
    end
  end

  def destroy
    @bgs = Bgs.find(params[:id],:include => :event)
    if Time.new > @bgs.event.bgs_by and not session[:staff]
      flash[:notice] = 'Cannot delete BGS after submission deadline'
    elsif not @bgs.answer.empty? and not session[:admin]
      flash[:notice] = 'Cannot delete skill after staff has answered it; time to negotiate'
    else
      @bgs.destroy
      flash[:notice] = 'Deleted BGS'
    end
    redirect_to :action => 'list', :event_id => @bgs.event_id, :char_id => @bgs.char_id
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
    "show" => "staff_or_owns", "list" => "staff_or_owns", 
    "edit" => "staff_or_owns", "update" => "staff_or_owns", 
    "destroy" => "admin_or_owns", "eventlist" => "staff_only",
    "assignto" => "staff_only", "submitanswer" => "staff_only",
    "fulllist" => "staff_only", "expand" => "staff_only",
    "comments" => "staff_only", "postcomment" => "staff_only",
    "assignee" => "staff_only", "deletecomment" => "staff_only"}

  around_filter do |controller, action| 
    method = @@perms[controller.action_name]
    if controller.params[:id]
      obj = Bgs.find(controller.params[:id])
    elsif controller.params[:char_id]
      obj = Char.find(controller.params[:char_id])
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
