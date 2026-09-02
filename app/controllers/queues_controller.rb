class QueuesController < ApplicationController
  # Jumps to a profile's current queue (creating one if needed).
  def current
    profile = Profile.find(params[:id])
    redirect_to queue_path(profile.current_queue)
  end

  def show
    @queue = ProfileQueue.includes(profile: :user).find(params[:id])
    @profile = @queue.profile
    @in_progress = @queue.in_progress_conversation
    # Active = pending + in_progress (unfinished, non-deleted), in the manual
    # drag-and-drop order, with the in-progress conversation pinned to the top.
    @conversations =
      @queue.conversations
            .active
            .ordered
            .includes(:answers)
            .partition(&:in_progress?)
            .flatten(1)
  end

  # Persists a drag-and-drop reorder. The client sends every active conversation
  # id in its new top-to-bottom order; positions are renumbered from zero.
  def reorder
    queue = ProfileQueue.find(params[:id])
    conversations = queue.conversations.active.where(id: reorder_ids).index_by(&:id)

    Conversation.transaction do
      reorder_ids.each_with_index do |id, index|
        conversations[id]&.update_column(:position, index)
      end
    end

    queue.broadcast_refresh_later

    head :no_content
  end

  private

  # Ids are looked up within this queue, so anything foreign or already
  # finished/deleted is simply ignored.
  def reorder_ids
    @reorder_ids ||= Array(params[:conversation_ids]).map(&:to_i)
  end
end
