require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper
  include ActiveJob::TestHelper

  setup do
    @queue = profile_queues(:alice_queue)
  end

  test "ordered sorts by position" do
    conversations(:catch_up).update!(position: 5)

    assert_equal [ "Weekly chat", "Catch-up" ], @queue.conversations.ordered.map(&:name)
  end

  test "a new conversation is positioned ahead of the existing ones" do
    conversation = @queue.conversations.create!(name: "Newest")

    assert_operator conversation.position, :<, @queue.conversations.where.not(id: conversation).minimum(:position)
    assert_equal "Newest", @queue.conversations.ordered.first.name
  end

  test "an explicit position is left alone" do
    conversation = @queue.conversations.create!(name: "Pinned last", position: 99)

    assert_equal 99, conversation.reload.position
  end

  test "active_conversations returns unfinished conversations in position order" do
    conversations(:catch_up).update!(position: 3)
    @queue.conversations.create!(name: "Gone", state: "deleted", position: 1)

    assert_equal [ "Weekly chat", "Catch-up" ], @queue.active_conversations.map(&:name)
  end

  test "adding a conversation refreshes everyone watching the queue" do
    assert_turbo_stream_broadcasts @queue, count: 1 do
      perform_enqueued_jobs { @queue.conversations.create!(name: "Newest") }
    end
  end

  test "starting a conversation refreshes everyone watching the queue" do
    stream = capture_turbo_stream_broadcasts @queue do
      perform_enqueued_jobs { conversations(:catch_up).in_progress! }
    end

    assert_equal [ "refresh" ], stream.map { |element| element["action"] }
  end

  test "removing a conversation refreshes everyone watching the queue" do
    assert_turbo_stream_broadcasts @queue, count: 1 do
      perform_enqueued_jobs { conversations(:catch_up).deleted! }
    end
  end

  test "a conversation refreshes its own queue, not another one" do
    assert_no_turbo_stream_broadcasts profile_queues(:bob_queue) do
      perform_enqueued_jobs { conversations(:catch_up).finished! }
    end
  end
end
