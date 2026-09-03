class Profile < ApplicationRecord
  belongs_to :user

  has_many :questions, -> { order(:position) }, dependent: :destroy, inverse_of: :profile
  has_many :queues, class_name: "ProfileQueue", dependent: :destroy, inverse_of: :profile
  has_many :interactions, through: :queues

  # A profile is generally listed by its user's name.
  def display_name
    user.name
  end

  def current_queue
    queues.find_by(current: true) || queues.create!(date: Date.current, current: true)
  end
end
