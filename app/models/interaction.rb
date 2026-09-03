class Interaction < ApplicationRecord
  belongs_to :queue, class_name: "ProfileQueue", inverse_of: :interactions

  has_many :answers, dependent: :destroy, inverse_of: :interaction

  accepts_nested_attributes_for :answers

  enum :state, { pending: "pending", in_progress: "in_progress", finished: "finished", deleted: "deleted" }

  validates :name, presence: true

  scope :active, -> { where(state: %w[pending in_progress]) }

  scope :ordered, -> { order(:position, created_at: :desc, id: :desc) }

  before_create :assign_position

  broadcasts_refreshes_to :queue

  def startable?
    pending? && queue.interactions.in_progress.none?
  end

  private

  def assign_position
    return if position_changed?

    self.position = (queue.interactions.minimum(:position) || 0) - 1
  end
end
