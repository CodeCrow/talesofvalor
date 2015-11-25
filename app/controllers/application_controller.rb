# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base

  helper :all # include all helpers, all the time

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery  :secret => '6ae00a792b81fe50b2d0167ddd72b761'
  
  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password"). 
  # filter_parameter_logging :password

  layout proc{ |c| c.request.xhr? ? false : "standard" }

  def self.everyone(session,obj)
    true
  end

  def self.any_user(session,obj)
    session[:user] ? true : false
  end

  def self.staff_only(session,obj)
    session[:staff] ? true : false
  end

  def self.admin_only(session,obj)
    session[:admin] ? true : false
  end

  def self.owns(session,obj)
    if obj.type <= Char
      return obj.player == session[:user]
    elsif obj.type <= Player
      return obj == session[:user]
    elsif obj.type <= Bgs
      return obj.char.player == session[:user]
    elsif obj.type <= Pel
      return obj.player == session[:user]
    end
  end      

  def self.admin_or_owns(session,obj)
    admin_only(session,obj) || owns(session,obj)
  end

  def self.staff_or_owns(session,obj)
    staff_only(session,obj) || owns(session,obj)
  end
end

# code for paginate_by_sql
module ActiveRecord
    class Base
        def self.find_by_sql_with_limit(sql, offset, limit)
            sql = sanitize_sql(sql)
            add_limit!(sql, {:limit => limit, :offset => offset})
            find_by_sql(sql)
        end

        def self.count_by_sql_wrapping_select_query(sql)
            sql = sanitize_sql(sql)
            count_by_sql("select count(*) from (#{sql}) as my_table")
        end
   end
end

class ApplicationController < ActionController::Base

    def paginate_by_sql(model, sql, per_page, options={})
       if options[:count]
           if options[:count].is_a? Integer
               total = options[:count]
           else
               total = model.count_by_sql(options[:count])
           end
       else
           total = model.count_by_sql_wrapping_select_query(sql)
       end
       object_pages = model.paginate(:total_entries => total, :page => params['page'], :per_page => per_page)
       # object_pages = Paginator.new self, total, per_page, params['page']
       objects = model.find_by_sql_with_limit(sql,
            object_pages.to_sql[1], per_page)
       return [object_pages, objects]
   end
end
