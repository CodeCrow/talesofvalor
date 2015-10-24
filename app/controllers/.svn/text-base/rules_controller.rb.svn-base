class RulesController < ApplicationController
  def index
    list
    render :action => 'list'
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :action => :list }

  verify :session => :admin, :except => [:index, :list, :show], :redirect_to => {:action => :list}, :add_flash => {:notice => "Only Site Administrators may edit rules"}

  def list
    @rule_pages, @rules = paginate :rules, :per_page => 10
  end

  def show
    @rule = Rule.find(params[:id])
  end

  def options
    if params[:type] == 'SkillRule'
      @opts = Skill.find(:all, :order => 'name')
    elsif params[:type] == 'HeaderRule'
      @opts = Header.find(:all, :order => 'name')
    elsif params[:type] == 'SkillGrantsHeaderRule'
      @opts = Skill.find(:all, :order => 'name')
    else
      @opts = Origin.find(:all, :order => 'type,name')
    end
    render :partial => "rules/options", :locals => {:opts => @opts.collect {|o| [o.name,o.id]}}
  end

  def new
    @rule = Rule.new
  end

  def create
    @rule = Rule.new(params[:rule])
    if @rule.save
      flash[:notice] = 'Rule was successfully created.'
      redirect_to :action => 'list'
    else
      render :action => 'new'
    end
  end

  def edit
    @rule = Rule.find(params[:id])
  end

  def update
    @rule = Rule.find(params[:id])
    if @rule.update_attributes(params[:rule])
      flash[:notice] = 'Rule was successfully updated.'
      redirect_to :action => 'show', :id => @rule
    else
      render :action => 'edit'
    end
  end

  def destroy
    Rule.find(params[:id]).destroy
    redirect_to :action => 'list'
  end
end
