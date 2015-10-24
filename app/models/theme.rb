class Theme
  @@themes = []

  def initialize
    @@themes = ["thin","wide","gray"]
  end
  
  def Theme.themes
    return @@themes
  end

end
