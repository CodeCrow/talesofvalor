class Race < Origin; end
class Background < Origin; end
class OriginsController < ApplicationController
  def index
    list
    render :action => 'list'
  end

  def list
    if session[:staff]
      @origins = Origin.find(:order => 'type,name')
      @origins = @origins.paginate(page: params[:page], per_page: 30)
    else
      @origins = Origin.where('hidden = 0', :order => 'type,name')
      @origins = @origins.paginate(:page => params[:page], :per_page => 30)
      #@origin_pages, @origins = paginate :origins, :per_page => 20, :order => 'type,name', :conditions => "hidden = 0"
    end
  end

  def show
    @origin = Origin.find(params[:id])
    if !session[:staff] and @origin.hidden
      flash[:notice] = 'That origin is hidden'
      redirect_to :action => :list
    end
  end

  def select
    if params[:value] && params[:value] != ""
      @origin = Origin.find(params[:value])
      if !session[:staff] and @origin.hidden == 1
        render :text => ""
      else
        @oskills = @origin.origin_skills
        render :partial => "origins/selectvalue", :locals => { :origin => @origin, :oskills => @oskills }
      end
    else
      render :text => ""
    end
  end

  def new
    @origin = Origin.new
  end

  def create
    if params[:origin][:type] == "Race"
      @origin = Race.new(params[:origin])
    else
      @origin = Background.new(params[:origin])
    end
    if @origin.save
      flash[:notice] = 'Origin was successfully created.'
      redirect_to :action => 'list'
    else
      render :action => 'new'
    end
  end

  def edit
    @origin = Origin.find(params[:id])
  end

  def update
    @origin = Origin.find(params[:id])
    if @origin.update_attributes(params[:origin])
      flash[:notice] = 'Origin was successfully updated.'
      @origin.reload
      redirect_to :action => 'show', :id => @origin
    else
      render :action => 'edit'
    end
  end

  def pick
    @origin = Origin.find(params[:id])
  end

  def addskill
    @origin = Origin.find(params[:id])
    
    @sk = Skill.find(params[:skill][:id])
    @count = params[:skill][:count].to_i

    @osk = OriginSkill.new(:skill => @sk, :origin => @origin, :count => @count);
    @osk.save!

    redirect_to :action => 'show', :id => @origin
  end

  def deleteskill

    OriginSkill.delete_all("origin_id = #{params[:id].to_i} and skill_id = #{params[:skill_id].to_i}")

    redirect_to :action => 'show', :id => params[:id]
  end


  def destroy
    Origin.find(params[:id]).destroy
    redirect_to :action => 'list'
  end
end
