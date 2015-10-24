class EventMessagesController < ApplicationController

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update ],
         :redirect_to => { :action => :list }

  verify :session => :staff, :redirect_to => {:controller => :players, :action => :welcome}, :add_flash => {:notice => "Only Staff may manipule event messages"}

  def new
    @event = Event.find(params[:event_id])
    @char  = Char.find(params[:char_id])
    @event_message = EventMessage.new(:event_id => @event.id, :char_id => @char.id)
  end

  def create
    @em = EventMessage.new(params[:event_message])
    @em.author_id = session[:user].id
    @em.submit_date = Time.new
    @em.save!
    flash[:notice] = 'Message was successfully saved.'
    redirect_to :action => :list, :event_id => @em.event_id, :char_id => @em.char_id
  end

  def edit
    @event_message = EventMessage.find(params[:id], :include => [:char, :event])
  end

  def update
    @em = EventMessage.find(params[:id])
    if @em.update_attributes(params[:event_message])
      flash[:notice] = 'Event was successfully updated.'
      redirect_to :action => 'list', :event_id => @em.event_id
    else
      render :action => 'edit'
    end
  end

  def list
    filter = {}
    if params[:event_id]
      @event = Event.find(params[:event_id])
      filter[:event_id] = @event.id
    end
    if params[:char_id]
      @char = Char.find(params[:char_id])
      filter[:char_id] = @char.id
    end
    if filter.empty?
      @event = Event.next
      filter[:event_id] = @event if @event
    end
    @emlist = EventMessage.find(:all,:conditions => filter, :include => "char")
  end

  def destroy
    em = EventMessage.find(params[:id])
    em.destroy
    redirect_to :action => 'list'
  end

end
