class PlayerLog < ActiveRecord::Base
  belongs_to :player
  before_create :set_timestamp

  private
    def set_timestamp
      self.ts = Time.now.utc.to_s(:db)
    end
end
