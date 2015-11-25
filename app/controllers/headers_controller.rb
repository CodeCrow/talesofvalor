class HeadersController < ApplicationController
  def index
    list
    render :action => 'list'
  end

  def list
    perpage = 15
    if session[:staff]
      filter = params[:filter] ? params[:filter] : 'all'
      params['page'] = params['page'] ? params['page'] : 1
      if filter == 'normal'
        @title = "Normal"
        @headers = Header.where("hidden = 0", :order => 'category, name')
        @headers = @headers.paginate(:page => params['page'], :per_page => perpage)
      elsif filter == 'hidden'
        @title = "Hidden"
        @headers = Header.where("hidden = 1", :order => 'category, name')
        @headers = @headers.paginate(:page => params['page'], :per_page => perpage)
      elsif filter == 'name'
        @title = "Name like #{params[:filtervalue]}"
        @headers = Header.where(["name like ?","%"+params[:filtervalue]+"%"], :order => 'category, name')
        @headers = @headers.paginate(:page => params['page'], :per_page => perpage)
      elsif filter == 'text'
        @title = "Text includes #{params[:filtervalue]}"
        @headers = Header.where(["description like ?","%"+params[:filtervalue]+"%"], :order => 'category, name')
        @headers = @headers.paginate(:page => params['page'], :per_page => perpage)
      elsif filter == 'category'
        @headers = Header.where(["category like ?","%"+params[:filtervalue]+"%"], :order => 'category, name')
        @headers = @headers.paginate(:page => params['page'], :per_page => perpage)
        @title = "Category like #{params[:filtervalue]}"
      else
        @headers = Header.where(:order => 'category, name')
        @headers = @headers.paginate(:page => params['page'], :per_page => perpage)
      end
    elsif !session[:user]
      @headers = Header.where('hidden=0', :order => 'category, name')
      @headers = @headers.paginate(:page => params['page'], :per_page => perpage)

    else
      @headers = Header.where('id in (#{session[:avail][:headers].keys.join(",")})', :order => 'category, name')
      @headers = @headers.paginate(:page => params['page'], :per_page => perpage)
    end
  end

  def show
    @header = Header.find(params[:id])
    @skheaders = @header.skill_headers.sort { |x,y| x.cost <=> y.cost }
    if session[:user]
      if !session[:staff] && !session[:avail][:headers][@header.id]
        flash[:notice] = 'You are not allowed to view that header'
        redirect_to :action => 'list'
      end
    elsif @header.hidden == 1
      flash[:notice] = 'You are not allowed to view that header'
      redirect_to :action => 'list'
    end
  end
  
  def new
    @header = Header.new
  end

  def create
    @header = Header.new(params[:header])
    if @header.save
      flash[:notice] = 'Header was successfully created.'
      redirect_to :action => 'list'
    else
      render :action => 'new'
    end
  end

  def edit
    @header = Header.find(params[:id])
  end

  def update
    @header = Header.find(params[:id])
    if @header.update_attributes(params[:header])
      flash[:notice] = 'Header was successfully updated.'
      redirect_to :action => 'show', :id => @header
    else
      render :action => 'edit'
    end
  end

  def destroy
    h = Header.find(params[:id])
    # remove skill associations -- not the actual skills
    SkillHeader.delete_all("header_id = #{h.id}")
    h.destroy
    redirect_to :action => 'list'
  end

  def print
    @header = Header.find(params[:id])
    @skheaders = @header.skill_headers.sort { |x,y| x.cost <=> y.cost }
    if session[:user]
      if !session[:staff] && !session[:avail][:headers][@header.id]
        flash[:notice] = 'You are not allowed to view that header'
        redirect_to :action => 'list'
      end
    elsif @header.hidden == 1
      flash[:notice] = 'You are not allowed to view that header'
      redirect_to :action => 'list'
    end

    _p = PDF::Writer.new :orientation => :landscape
    _p.select_font 'Times-Roman'
    _p.start_columns

    @header.write_to_pdf(_p)
    
    send_data _p.render, :filename => @header.name+'.pdf', :type => "application/pdf"
  end

end
