require "test_helper"

class ConversationTest < ActiveSupport::TestCase
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
end
