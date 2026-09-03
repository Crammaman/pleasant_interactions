# The domain concept is a "Queue", but Ruby reserves ::Queue, so the class is
# ProfileQueue backed by the `queues` table. Associations still use queue naming.
class ProfileQueue < ApplicationRecord
  self.table_name = "queues"

  belongs_to :profile

  has_many :interactions, foreign_key: :queue_id, dependent: :destroy, inverse_of: :queue

  scope :current, -> { where(current: true) }

  def active_interactions
    interactions.active.ordered
  end

  def in_progress_interaction
    interactions.in_progress.first
  end
end
