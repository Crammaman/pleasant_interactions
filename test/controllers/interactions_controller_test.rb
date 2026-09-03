require "test_helper"

class InteractionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    post login_path, params: { username: "admin", password: "password123" }
    @queue = profile_queues(:alice_queue)
  end

  # The answer fields the form renders, keyed the way Rails nests them.
  def answers_attributes(*rows)
    rows.each_with_index.to_h { |row, index| [ index.to_s, row ] }
  end

  # Ids of the existing answers the edit form submits back.
  def rendered_answer_ids
    css_select("input[type=hidden]").filter_map { |input| input["value"] if input["name"].to_s.end_with?("[id]") }
  end

  test "new builds one answer per profile question in order" do
    get new_queue_interaction_path(@queue)
    assert_response :success
    assert_match(/How are you feeling today\?/, response.body)
    assert_match(/Preferred topic/, response.body)
    assert_match(/Length of chat/, response.body)
  end

  test "create makes an interaction with nested answers" do
    assert_difference -> { @queue.interactions.count }, 1 do
      assert_difference -> { Answer.count }, 3 do
        post queue_interactions_path(@queue), params: {
          interaction: {
            name: "Evening chat",
            answers_attributes: {
              "0" => { question_id: questions(:feeling).id, value: "Great" },
              "1" => { question_id: questions(:topic).id, value: "Work" },
              "2" => { question_id: questions(:length).id, value: "Short" }
            }
          }
        }
      end
    end

    interaction = @queue.interactions.order(:created_at).last
    assert_redirected_to queue_path(@queue)
    assert_equal "Evening chat", interaction.name
    assert_equal "pending", interaction.state
    # question_text is snapshotted from the question.
    assert_equal "How are you feeling today?",
                 interaction.answers.find_by(question_id: questions(:feeling).id).question_text
  end

  test "create re-renders new on invalid input" do
    assert_no_difference -> { Interaction.count } do
      post queue_interactions_path(@queue), params: {
        interaction: { name: "" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "start sets a pending interaction to in_progress" do
    interaction = interactions(:catch_up)
    patch start_interaction_path(interaction)
    assert_redirected_to queue_path(@queue)
    assert_equal "in_progress", interaction.reload.state
  end

  test "edit requires login" do
    delete logout_path
    get edit_interaction_path(interactions(:catch_up))
    assert_redirected_to login_path
  end

  test "edit renders the interaction and its answers" do
    interaction = interactions(:catch_up)
    get edit_interaction_path(interaction)
    assert_response :success

    assert_select "h1", /Edit Interaction/
    assert_select "input[name=?][value=?]", "interaction[name]", interaction.name
    assert_match(/Doing well, thanks!/, response.body)
    assert_equal interaction.answers.pluck(:id).map(&:to_s).sort, rendered_answer_ids.sort
  end

  test "edit builds a blank answer for a question added since" do
    interaction = interactions(:catch_up)
    assert_not interaction.answers.exists?(question: questions(:length))

    get edit_interaction_path(interaction)
    assert_response :success

    # The unanswered question is offered, and only the answered ones carry ids.
    assert_match(/Length of chat/, response.body)
    assert_equal 2, rendered_answer_ids.count
  end

  test "edit falls back to a text box for an answer whose question is gone" do
    answer = answers(:catch_up_topic)
    answer.update!(question_id: nil)

    get edit_interaction_path(interactions(:catch_up))
    assert_response :success

    # The snapshot still labels it and its value moves to a plain text box...
    assert_match(/Preferred topic/, response.body)
    assert_select "input[type=text][value=?]", answer.value
    # ...while the question itself, now unanswered, is offered afresh.
    assert_select "select", 1
  end

  test "update edits the name and existing answers in place" do
    interaction = interactions(:catch_up)
    feeling = answers(:catch_up_feeling)
    topic = answers(:catch_up_topic)

    assert_no_difference("Answer.count") do
      patch interaction_path(interaction), params: {
        interaction: {
          name: "Renamed catch-up",
          answers_attributes: answers_attributes(
            { id: feeling.id, value: "Much better" },
            { id: topic.id, value: "Work" }
          )
        }
      }
    end

    assert_redirected_to queue_path(@queue)
    assert_equal "Interaction updated.", flash[:notice]
    assert_equal "Renamed catch-up", interaction.reload.name
    assert_equal "Much better", feeling.reload.value
    assert_equal "Work", topic.reload.value
  end

  test "update leaves the question_text snapshot alone" do
    feeling = answers(:catch_up_feeling)
    questions(:feeling).update!(text: "How's your day?")

    patch interaction_path(interactions(:catch_up)), params: {
      interaction: {
        name: "Catch-up",
        answers_attributes: answers_attributes({ id: feeling.id, value: "Fine" })
      }
    }

    assert_equal "How are you feeling today?", feeling.reload.question_text
  end

  test "update answers a question added since the interaction was created" do
    interaction = interactions(:catch_up)

    assert_difference("Answer.count", 1) do
      patch interaction_path(interaction), params: {
        interaction: {
          name: "Catch-up",
          answers_attributes: answers_attributes(
            { question_id: questions(:length).id, question_text: questions(:length).text, value: "Short" }
          )
        }
      }
    end

    added = interaction.answers.find_by(question: questions(:length))
    assert_equal "Short", added.value
    assert_equal "Length of chat", added.question_text
  end

  test "update re-renders edit when the interaction is invalid" do
    interaction = interactions(:catch_up)

    patch interaction_path(interaction), params: {
      interaction: {
        name: "",
        answers_attributes: answers_attributes({ id: answers(:catch_up_feeling).id, value: "Kept" })
      }
    }

    assert_response :unprocessable_entity
    assert_select "h1", /Edit Interaction/
    assert_equal "Catch-up", interaction.reload.name
    assert_equal "Doing well, thanks!", answers(:catch_up_feeling).reload.value
    # What was typed comes back rather than the stored value.
    assert_select "input[name=?][value=?]", "interaction[answers_attributes][0][value]", "Kept"
  end

  test "start is rejected while another interaction is in progress" do
    interactions(:catch_up).update!(state: "in_progress")
    other = interactions(:weekly_chat)

    patch start_interaction_path(other)
    assert_redirected_to queue_path(@queue)
    assert_equal "pending", other.reload.state
    follow_redirect!
    assert_match(/already in progress/, response.body)
  end

  test "finish moves an in-progress interaction to finished" do
    interaction = interactions(:catch_up)
    interaction.update!(state: "in_progress")

    patch finish_interaction_path(interaction)
    assert_redirected_to queue_path(@queue)
    assert_equal "finished", interaction.reload.state
  end

  test "finish is rejected for a pending interaction" do
    interaction = interactions(:catch_up)
    patch finish_interaction_path(interaction)
    assert_equal "pending", interaction.reload.state
  end

  test "remove soft-deletes the interaction" do
    interaction = interactions(:catch_up)
    patch remove_interaction_path(interaction)
    assert_redirected_to queue_path(@queue)
    assert_equal "deleted", interaction.reload.state
  end
end
