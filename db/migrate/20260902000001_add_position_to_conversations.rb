class AddPositionToConversations < ActiveRecord::Migration[8.1]
  def up
    add_column :conversations, :position, :integer, null: false, default: 0
    add_index :conversations, [ :queue_id, :position ]

    # Backfill in the order the queue used to render before positions existed:
    # newest first, numbered per queue.
    say_with_time "backfilling conversation positions" do
      queue_ids = select_values("SELECT DISTINCT queue_id FROM conversations").map { |id| Integer(id) }

      queue_ids.each do |queue_id|
        ids = select_values(
          "SELECT id FROM conversations WHERE queue_id = #{queue_id} ORDER BY created_at DESC, id DESC"
        ).map { |id| Integer(id) }

        ids.each_with_index do |id, index|
          execute "UPDATE conversations SET position = #{index} WHERE id = #{id}"
        end
      end
    end
  end

  def down
    remove_index :conversations, [ :queue_id, :position ]
    remove_column :conversations, :position
  end
end
