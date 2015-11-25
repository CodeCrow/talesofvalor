class SkillsController < ApplicationController
  def index
    list
    render :action => 'list'
  end

  def list
    params[:filter] = 'standard' unless session[:staff]
    @filter = params[:filter] ? params[:filter] : 'standard'    
    if params[:filter] == 'standard'
      sql = 'select s.* from skills s, skill_headers sh LEFT JOIN headers h on sh.header_id = h.id where s.id = sh.skill_id and (sh.header_id=0 or (sh.header_id is not null and h.hidden = 0)) order by s.name'
      @skills = Skill.paginate_by_sql(sql, :per_page => 30, :page => params['page'])
    elsif params[:filter] == 'hidden'
      sql = 'select s.* from skills s, skill_headers sh, headers h where s.id = sh.skill_id and sh.header_id=h.id and h.hidden = 1 order by s.name'
      @skills = Skill.paginate_by_sql(sql, :per_page => 30, :page => params['page'])
    elsif params[:filter] == 'unlinked'
      sql = 'select s.* from skills s LEFT JOIN skill_headers sh on s.id=sh.skill_id where sh.skill_id is null order by s.name'
      @skills = Skill.paginate_by_sql(sql, :per_page => 30, :page => params['page'])
    elsif params[:filter] == 'name'
      @skill_pages, @skills = paginate :skill, :per_page => 30, :order => "name", :conditions => ["name like ?","%"+params[:filtervalue]+"%"]
    elsif params[:filter] == 'bgs'
      @skill_pages, @skills = paginate :skill, :per_page => 30, :order => "name", :conditions => ["bgs = 1"]
    elsif params[:filter] == 'desc'
      @skill_pages, @skills = paginate :skill, :per_page => 30, :order => "name", :conditions => ["description like ?","%"+params[:filtervalue]+"%"]
    else
      @skill_pages, @skills = paginate :skill, :per_page => 30, :order => "name"
    end
#    @skill_pages = Paginator.new self, Skill.count_by_sql("select COUNT(*) from skills s #{sql}"), 30, params[:page]
#    @skills = Skill.find_by_sql("select s.* from skills s #{sql} group by s.id order by s.name limit #{@skill_pages.items_per_page} offset #{@skill_pages.current.offset}");
  # @skill_pages, @skills = paginate :skills, :per_page => 30, :order => 'name'
  end

  def tree
    if session[:staff]
      @skheaders = SkillHeader.find_by_sql("select sh.* from skill_headers sh, headers h where h.id = sh.header_id order by h.category,h.name,sh.cost")
    else
      @skheaders = SkillHeader.find_by_sql("select sh.* from skill_headers sh, headers h where h.id = sh.header_id and h.hidden = 0 order by h.category,h.name,sh.cost")
    end
    @opensk = SkillHeader.find_by_sql("select sh.* from skill_headers sh, skills s where s.id = sh.skill_id and sh.header_id = 0 order by s.tag,sh.cost")
  end
   
  def show
    @skill = Skill.find(params[:id])
    @skheaders = @skill.skill_headers
    if session[:user]
      if !session[:staff] && !session[:avail][:skills][@skill.id]
        flash[:notice] = "Unable to view that skill"
        redirect_to :controller => 'players', :action => "show", :id => session[:user]
      end
    else
      if !@skheaders.collect {|skh| (skh.header_id = 0 || skh.header.hidden = 0) ? skh : nil}.compact
        flash[:notice] = "Unable to view that skill"
        redirect_to :action => "list"
      end
    end
  end

  def new
    @skill = Skill.new
    @skheaders = []
    @headers = Header.find :all, :order => 'name'
  end

  def create
    @skill = Skill.new(params[:skill])
    if @skill.save
      if params[:skh][:new][:id].to_i >= 0
        @skh = SkillHeader.new(:skill => @skill, :header_id => params[:skh][:new][:id], :cost => params[:skh][:new][:cost], :dabble => params[:skh][:new][:dabble].to_i > 0);
        @skh.save!
      end
      flash[:notice] = 'Skill was successfully created.'
      redirect_to :action => 'list'
    else
      render :action => 'new'
    end
  end

  def edit
    @skill = Skill.find(params[:id])
    @skheaders = @skill.skill_headers
    @headers = Header.find :all, :order => 'name'
  end

  def update
    @skill = Skill.find(params[:id])
    if @skill.update_attributes(params[:skill])
      for k in params[:skh].keys
        if k == "new"
          if params[:skh][:new][:id].to_i >= 0
            @skh = SkillHeader.new(:skill => @skill, :header_id => params[:skh][:new][:id], :cost => params[:skh][:new][:cost], :dabble => params[:skh][:new][:dabble].to_i > 0);
            @skh.save!
          end
        else
          @skh = SkillHeader.find_by_sql(['select skill_id,header_id,cost,dabble from skill_headers where skill_id=? and header_id=?', @skill.id, k]).pop
          if @skh.cost != params[:skh][k].to_i
            @skh.connection.update("update skill_headers set cost = #{params[:skh][k].to_i} where skill_id=#{@skill.id} and header_id=#{k}");
          end
        end
      end
      flash[:notice] = 'Skill was successfully updated.'
      redirect_to :action => 'show', :id => @skill
    else
      render :action => 'edit'
    end
  end

  def destroy
    s = Skill.find(params[:id])
    # remove skill associations -- not the actual skills
    SkillHeader.delete_all("skill_id = #{s.id}")
    s.destroy
    redirect_to :action => 'list'
  end

  def pickheader
    @skill = Skill.find(params[:id])
    @headers = Header.find_all :order => 'name'
  end

  def deleteheader
    @skill = Skill.find(params[:id])
    SkillHeader.delete_all("skill_id = #{@skill.id} and header_id = #{params[:header_id].to_i}");

    redirect_to :action => 'show', :id => @skill
  end

end
