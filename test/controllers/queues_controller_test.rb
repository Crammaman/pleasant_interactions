require "test_helper"

class QueuesControllerTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper
  include ActiveJob::TestHelper

  setup do
    post login_path, params: { username: "admin", password: "password123" }
    @queue = profile_queues(:alice_queue)
    @profile = profiles(:alice_profile)
  end

  test "current redirects to the profile's current queue" do
    get queue_profile_path(@profile)
    assert_redirected_to queue_path(@profile.current_queue)
  end

  test "current creates a queue when none is current" do
    profile = profiles(:bob_profile)
    profile.queues.update_all(current: false)

    get queue_profile_path(profile)
    assert_response :redirect
    assert profile.reload.current_queue.current?
  end

  test "show lists only active interactions" do
    finished = interactions(:catch_up)
    finished.update!(state: "finished")
    deleted = interactions(:weekly_chat)
    deleted.update!(state: "deleted")

    get queue_path(@queue)
    assert_response :success
    assert_no_match(/Catch-up/, response.body)
    assert_no_match(/Weekly chat/, response.body)
  end

  test "show renders active interactions and their answers" do
    get queue_path(@queue)
    assert_response :success
    assert_match(/Catch-up/, response.body)
    assert_match(/Weekly chat/, response.body)
    assert_match(/Doing well, thanks!/, response.body)
    assert_match(/How are you feeling today\?/, response.body)
  end

  test "show pins the in-progress interaction first" do
    interactions(:catch_up).update!(state: "in_progress")

    get queue_path(@queue)
    assert_response :success
    assert_operator response.body.index("Catch-up"), :<, response.body.index("Weekly chat")
  end

  test "show lists interactions in their stored order" do
    interactions(:catch_up).update!(position: 5)

    get queue_path(@queue)
    assert_response :success
    assert_operator response.body.index("Weekly chat"), :<, response.body.index("Catch-up")
  end

  test "show pins the in-progress interaction above a lower-positioned one" do
    interactions(:catch_up).update!(state: "in_progress", position: 99)

    get queue_path(@queue)
    assert_response :success
    assert_operator response.body.index("Catch-up"), :<, response.body.index("Weekly chat")
  end

  test "show marks the in-progress interaction as locked and gives it no drag handle" do
    interactions(:catch_up).update!(state: "in_progress")

    get queue_path(@queue)
    assert_response :success
    assert_select "div.card.is-locked", 1
    assert_select "div.card.is-locked [data-queue-sort-handle]", 0
    assert_select "div.card:not(.is-locked) [data-queue-sort-handle]", 1
  end

  test "show gives every card an edit link, in progress or not" do
    interactions(:catch_up).update!(state: "in_progress")

    get queue_path(@queue)
    assert_response :success
    # .interaction-card is the hook the footer's equal-width rule is scoped to.
    assert_select "div.card.interaction-card.is-locked footer a.card-footer-item[href=?]",
                  edit_interaction_path(interactions(:catch_up)), 1
    assert_select "div.card.interaction-card:not(.is-locked) footer a.card-footer-item[href=?]",
                  edit_interaction_path(interactions(:weekly_chat)), 1
  end

  test "show makes the whole header of a movable card the drag handle" do
    interactions(:catch_up).update!(state: "in_progress")

    get queue_path(@queue)
    assert_response :success
    # The handle is the header itself, not a grip inside it.
    assert_select "div.card:not(.is-locked) > header.card-header.interaction-drag-header[data-queue-sort-handle]", 1
    assert_select "div.card:not(.is-locked) > header .interaction-handle[data-queue-sort-handle]", 0
    assert_select "div.card.is-locked > header.interaction-drag-header", 0
  end

  test "reorder renumbers positions from the submitted order" do
    catch_up = interactions(:catch_up)
    weekly = interactions(:weekly_chat)

    patch reorder_queue_path(@queue), params: { interaction_ids: [ weekly.id, catch_up.id ] }, as: :json

    assert_response :no_content
    assert_equal 0, weekly.reload.position
    assert_equal 1, catch_up.reload.position
  end

  test "show subscribes to the queue's stream and asks for morphing refreshes" do
    get queue_path(@queue)
    assert_response :success
    assert_select "turbo-cable-stream-source[signed-stream-name=?]", signed_stream_name(@queue)
    assert_select "meta[name='turbo-refresh-method'][content='morph']", 1
    assert_select "meta[name='turbo-refresh-scroll'][content='preserve']", 1
  end

  test "reorder refreshes everyone watching the queue" do
    catch_up = interactions(:catch_up)
    weekly = interactions(:weekly_chat)

    assert_turbo_stream_broadcasts @queue, count: 1 do
      perform_enqueued_jobs do
        patch reorder_queue_path(@queue),
              params: { interaction_ids: [ weekly.id, catch_up.id ] }, as: :json
      end
    end
  end

  test "reorder ignores ids from another queue" do
    other = interactions(:bob_chat)
    weekly = interactions(:weekly_chat)

    # `other` sits at index 1, so it would be renumbered to 1 if the action
    # were not scoped to this queue.
    patch reorder_queue_path(@queue),
          params: { interaction_ids: [ weekly.id, other.id ] }, as: :json

    assert_response :no_content
    assert_equal 0, other.reload.position, "an interaction in another queue must not move"
    assert_equal 0, weekly.reload.position
  end

  test "reorder ignores interactions that are no longer active" do
    catch_up = interactions(:catch_up)
    catch_up.update!(state: "finished", position: 7)

    patch reorder_queue_path(@queue),
          params: { interaction_ids: [ catch_up.id, interactions(:weekly_chat).id ] }, as: :json

    assert_response :no_content
    assert_equal 7, catch_up.reload.position
  end

  test "reorder requires a logged-in user" do
    delete logout_path

    patch reorder_queue_path(@queue),
          params: { interaction_ids: [ interactions(:weekly_chat).id ] }, as: :json

    assert_redirected_to login_path
    assert_equal 1, interactions(:weekly_chat).reload.position
  end

  test "show renders an empty state when no active interactions" do
    @queue.interactions.update_all(state: "deleted")

    get queue_path(@queue)
    assert_response :success
    assert_match(/No interactions in this queue yet/, response.body)
  end
end
