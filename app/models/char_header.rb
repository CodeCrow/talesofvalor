class CharHeader < ActiveRecord::Base
  belongs_to :char
  belongs_to :header
end
