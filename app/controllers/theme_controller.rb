class ThemeController < ApplicationController
  helper ApplicationHelper
  
  def changeTheme
    @new_theme = params[:new_theme]
    session[:theme] = @new_theme
    render :text => "updated"
  end
    
end
