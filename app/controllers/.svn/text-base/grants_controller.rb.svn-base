class GrantsController < ApplicationController
  def index
    list
    render :action => 'list'
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :action => :list }

  def list
    @grant_pages, @grants = paginate :grants, :per_page => 10
  end

  def show
    @grant = Grant.find(params[:id])
  end

  def new
    @grant = Grant.new
  end

  def create
    @grant = Grant.new(params[:grant])
    if @grant.save
      flash[:notice] = 'Grant was successfully created.'
      redirect_to :action => 'list'
    else
      render :action => 'new'
    end
  end

  def edit
    @grant = Grant.find(params[:id])
  end

  def update
    @grant = Grant.find(params[:id])
    if @grant.update_attributes(params[:grant])
      flash[:notice] = 'Grant was successfully updated.'
      redirect_to :action => 'show', :id => @grant
    else
      render :action => 'edit'
    end
  end

  def destroy
    Grant.find(params[:id]).destroy
    redirect_to :action => 'list'
  end
end
