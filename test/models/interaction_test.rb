require "test_helper"

class InteractionTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper
  include ActiveJob::TestHelper

  setup do
    @queue = profile_queues(:alice_queue)
  end

  test "ordered sorts by position" do
    interactions(:catch_up).update!(position: 5)

    assert_equal [ "Weekly chat", "Catch-up" ], @queue.interactions.ordered.map(&:name)
  end

  test "a new interaction is positioned ahead of the existing ones" do
    interaction = @queue.interactions.create!(name: "Newest")

    assert_operator interaction.position, :<, @queue.interactions.where.not(id: interaction).minimum(:position)
    assert_equal "Newest", @queue.interactions.ordered.first.name
  end

  test "an explicit position is left alone" do
    interaction = @queue.interactions.create!(name: "Pinned last", position: 99)

    assert_equal 99, interaction.reload.position
  end

  test "active_interactions returns unfinished interactions in position order" do
    interactions(:catch_up).update!(position: 3)
    @queue.interactions.create!(name: "Gone", state: "deleted", position: 1)

    assert_equal [ "Weekly chat", "Catch-up" ], @queue.active_interactions.map(&:name)
  end

  test "adding an interaction refreshes everyone watching the queue" do
    assert_turbo_stream_broadcasts @queue, count: 1 do
      perform_enqueued_jobs { @queue.interactions.create!(name: "Newest") }
    end
  end

  test "starting an interaction refreshes everyone watching the queue" do
    stream = capture_turbo_stream_broadcasts @queue do
      perform_enqueued_jobs { interactions(:catch_up).in_progress! }
    end

    assert_equal [ "refresh" ], stream.map { |element| element["action"] }
  end

  test "removing an interaction refreshes everyone watching the queue" do
    assert_turbo_stream_broadcasts @queue, count: 1 do
      perform_enqueued_jobs { interactions(:catch_up).deleted! }
    end
  end

  test "an interaction refreshes its own queue, not another one" do
    assert_no_turbo_stream_broadcasts profile_queues(:bob_queue) do
      perform_enqueued_jobs { interactions(:catch_up).finished! }
    end
  end
end
