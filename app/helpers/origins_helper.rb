module OriginsHelper

  def selector(type)
    if session[:staff]
      return select('origin', type, Origin.find(:all, :order => 'name',
                                                :conditions => { :type => type }
                                                ).collect {|o| [o.name, o.id] },
                    {:include_blank => true })
    else
      return select('origin', type, Origin.find(:all, :order => 'name', 
                                                :conditions => { :type => type,
                                                  :hidden => false }
                                                ).collect {|o| [o.name, o.id] },
                    {:include_blank => true })
    end
    
  end

end
