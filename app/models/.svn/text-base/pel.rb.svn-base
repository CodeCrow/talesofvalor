class Pel < ActiveRecord::Base
  belongs_to :player
  belongs_to :event
  belongs_to :char

  def overallSize
    return self.likes.size() +
      self.dislikes.size() +
      self.bestmoments.size() +
      self.worstmoments.size() +
      self.learned.size() +
      self.data.size()
  end

  def self.minSize
    return 500
  end
end
