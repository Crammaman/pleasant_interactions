class Answer < ApplicationRecord
  belongs_to :interaction, inverse_of: :answers
  # Optional so answers survive their question being deleted; question_text is
  # the snapshot of the question's text from when the answer was created.
  belongs_to :question, optional: true

  before_validation :snapshot_question_text, on: :create

  validates :question_text, presence: true

  private

  def snapshot_question_text
    self.question_text ||= question&.text
  end
end
