class Bgs < ActiveRecord::Base
  belongs_to :event
  belongs_to :player
  belongs_to :char
  belongs_to :skill
  belongs_to :answering_player, :class_name => "Player", :foreign_key => :answering_player_id

  def write_to_pdf(_p)
    _p.text "<b>#{self.question}</b> (#{self.count} #{self.skill.name} - #{self.submit_date.strftime("%d %b %Y")}):", :font_size => 12
    _p.text self.answer.gsub(/\342|\200|\234|\235|\231|\303\|\240|\246|\206|\222/,'')
  end
end
