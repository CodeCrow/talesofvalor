class TagsController < ApplicationController
  def index
    list
    render :action => 'list'
  end

  verify :session => :staff, :redirect_to => {:controller => :players, :action => :welcome}, :add_flash => {:notice => "Only Staff may manipulate tags"}

  def list
    @tags = TagDescription.find(:all)
    @counts = {}
    Tag.find_by_sql("select tag,count(*) as count from tags group by tag").each {|t| @counts[t.tag] = t.count }
  end
  
  def show
    @tag = TagDescription.find(:first,:conditions => {:tag => params[:tag]}, :include => :owner)
    @players = PlayerTag.find(:all, :conditions => {:tag => params[:tag]}).collect {|pt| pt.player}.compact
    @chars = CharTag.find(:all, :conditions => {:tag => params[:tag]}).collect {|ct| ct.char}.compact
    @headers = HeaderTag.find(:all, :conditions => {:tag => params[:tag]}).collect {|st| st.header }.compact
    @skills = SkillTag.find(:all, :conditions => {:tag => params[:tag]}).collect {|st| st.skill }.compact
    @bgs = BGSTag.find(:all, :conditions => {:tag => params[:tag]}).collect {|bt| bt.bgs}.compact
    @pels = PELTag.find(:all, :conditions => {:tag => params[:tag]}).collect {|pt| pt.pel}.compact
  end

  def new
    @tag_description = TagDescription.new
    @staff = Player.find(:all,:conditions => "acl != 'Player'", :order => "name").collect {|p| [p.name,p.id]}
  end

  def create
    @tag_description = TagDescription.new(params[:tag_description])
    @tag_description.id = params[:tag_description][:tag]
    if @tag_description.save
      @tag = Tag.new
      @tag.id = @tag_description.id
      @tag.foreign_id = @tag_description.owner_id
      @tag.type = "PlayerTag"
      @tag.save!
      flash[:notice] = 'TagDescription was successfully updated.'
      redirect_to :action => 'show', :tag => @tag_description.tag
    else
      @staff = Player.find(:all,:conditions => "acl != 'Player'", :order => "name").collect {|p| [p.name,p.id]}
      render :action => 'edit'
    end
  end

  def edit
    @tag_description = TagDescription.find(:first, :conditions => {:tag => params[:tag]})
    if not @tag_description
      flash[:notice] = "Unable to find a tag named #{params[:tag]}."
      redirect_to :action => :list
    end
    @staff = Player.find(:all,:conditions => "acl != 'Player'", :order => "name").collect {|p| [p.name,p.id]}
  end

  def update
    @tag_description = TagDescription.find(:first, :conditions => {:tag => params[:tag_description][:tag]})
    old_owner_id = @tag_description.owner_id
    if @tag_description.update_attributes(params[:tag_description])
      if (old_owner_id != @tag_description.owner_id and not Tag.find(:first, :conditions => {:tag => @tag_description.tag, :foreign_id => @tag_description.owner_id, :type => "PlayerTag"}))
        @tag = Tag.new
        @tag.id = @tag_description.id
        @tag.foreign_id = @tag_description.owner_id
        @tag.type = "PlayerTag"
        @tag.save!
      end
      flash[:notice] = 'TagDescription was successfully updated.'
      redirect_to :action => 'show', :tag => @tag_description.tag
    else
      @staff = Player.find(:all,:conditions => "acl != 'Player'", :order => "name").collect {|p| [p.name,p.id]}
      render :action => 'edit'
    end
  end

  def destroy
    @td = TagDescription.find(params[:tag])
    @td.destroy
    Tag.delete_all(:tag => params[:tag])
    redirect_to :action => :list
  end

  def showtagger
    tags = TagDescription.find_by_sql("select tag from tag_descriptions order by tag").collect {|td| td.tag}
    tags = ["Select"].concat tags
    render :partial => "tagger", :locals => {:tags => tags, :id => params[:id], :type => params[:type]}
  end

  def addtag
    @id = params[:id]
    @type = params[:type]
    @tagname = params[:tag]
    if @tagname != 'Select' and Tag.find(:all,:conditions => {:tag => @tagname, :foreign_id => @id, :type => @type}).empty?
      @tag = Tag.new
      @tag.id = @tagname
      @tag.foreign_id = @id
      @tag.type = @type
      @tag.save!
    end
    render :partial => "tagbutton", :locals => {:id => @id, :type => @type}
  end

  def untag
    Tag.delete_all(:tag => params[:tag], :foreign_id => params[:id], :type => params[:type])
    redirect_to :action => :show, :tag => params[:tag]
  end
end
