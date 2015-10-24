class EventMessage < ActiveRecord::Base
  belongs_to :event
  belongs_to :char
  belongs_to :author, :class_name => "Player", :foreign_key => :author_id

  def write_to_pdf(_p)
    _p.text "<C:bullet />"+self.message.gsub(/\342|\200|\234|\235|\231|\303\|\240|\246|\206|\222/,''), :font_size => 10, :left => 10    
  end
end
