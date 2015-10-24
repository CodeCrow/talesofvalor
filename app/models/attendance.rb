class Attendance < ActiveRecord::Base
  belongs_to :player
  belongs_to :event
  belongs_to :char
end
