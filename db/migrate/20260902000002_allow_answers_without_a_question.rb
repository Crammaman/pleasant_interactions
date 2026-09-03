# The Answer model and the original migration both intend question_id to be
# nullable so answers outlive a deleted question (question_text is the
# snapshot), but the column landed NOT NULL.
class AllowAnswersWithoutAQuestion < ActiveRecord::Migration[8.1]
  def change
    change_column_null :answers, :question_id, true
  end
end
