# The domain language is now "interaction"; the table and the answers foreign
# key follow. The earlier create_conversations/add_position migrations are left
# as-is: they record what already ran.
class RenameConversationsToInteractions < ActiveRecord::Migration[8.1]
  def change
    rename_table :conversations, :interactions
    rename_column :answers, :conversation_id, :interaction_id
  end
end
