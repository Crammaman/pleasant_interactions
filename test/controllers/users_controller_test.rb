require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  def login_as(username = "admin")
    post login_path, params: { username: username, password: "password123" }
  end

  # The form submits a row per question; an id means "update this one".
  def question_row(question = nil, **overrides)
    {
      id: question&.id,
      text: question&.text,
      question_type: question&.question_type,
      options: question ? question.options.join("\n") : ""
    }.merge(overrides)
  end

  test "new requires login" do
    get new_user_path
    assert_redirected_to login_path
  end

  test "new renders when logged in" do
    login_as
    get new_user_path
    assert_response :success
    assert_select "h1", "Add User"
  end

  test "create user without converser creates no profile" do
    login_as
    assert_difference("User.count", 1) do
      assert_no_difference("Profile.count") do
        post users_path, params: {
          user: {
            username: "carol",
            name: "Carol Smith",
            password: "password123",
            password_confirmation: "password123"
          },
          converser: "0"
        }
      end
    end
    assert_redirected_to root_path
    assert_equal "User created", flash[:notice]
    assert_nil User.find_by(username: "carol").profile
  end

  test "create ignores questions when converser is off" do
    login_as
    assert_no_difference("Question.count") do
      post users_path, params: {
        user: {
          username: "dave",
          name: "Dave Jones",
          password: "password123",
          password_confirmation: "password123"
        },
        converser: "0",
        questions: [ { text: "Ignored", question_type: "text", options: "" } ]
      }
    end
  end

  test "create with converser and questions creates profile and questions" do
    login_as
    assert_difference([ "User.count", "Profile.count" ], 1) do
      assert_difference("Question.count", 2) do
        post users_path, params: {
          user: {
            username: "erin",
            name: "Erin Fox",
            password: "password123",
            password_confirmation: "password123"
          },
          converser: "1",
          questions: [
            { text: "How are you?", question_type: "text", options: "" },
            { text: "Pick one", question_type: "select", options: "A\nB\nC" }
          ]
        }
      end
    end

    assert_redirected_to root_path
    profile = User.find_by(username: "erin").profile
    assert_not_nil profile

    questions = profile.questions.order(:position).to_a
    assert_equal [ 1, 2 ], questions.map(&:position)

    text_q = questions.first
    assert_equal "How are you?", text_q.text
    assert_equal "text", text_q.question_type
    assert_equal({}, text_q.config)

    select_q = questions.second
    assert_equal "select", select_q.question_type
    assert_equal({ "options" => %w[A B C] }, select_q.config)
  end

  test "create skips blank question rows" do
    login_as
    assert_difference("Question.count", 1) do
      post users_path, params: {
        user: {
          username: "frank",
          name: "Frank Hill",
          password: "password123",
          password_confirmation: "password123"
        },
        converser: "1",
        questions: [
          { text: "  ", question_type: "text", options: "" },
          { text: "Real question", question_type: "text", options: "" }
        ]
      }
    end
    profile = User.find_by(username: "frank").profile
    assert_equal 1, profile.questions.count
    assert_equal 1, profile.questions.first.position
  end

  test "edit requires login" do
    get edit_user_path(users(:alice))
    assert_redirected_to login_path
  end

  test "edit renders the user's current details" do
    login_as
    get edit_user_path(users(:alice))
    assert_response :success
    assert_select "h1", "Edit User"
    assert_select "input[value=?]", "alice"
    assert_select "input[value=?]", "Alice Nguyen"
  end

  test "update changes user details" do
    login_as
    patch user_path(users(:alice)), params: {
      user: { username: "alice2", name: "Alice Two", password: "", password_confirmation: "" }
    }
    assert_redirected_to root_path
    assert_equal "User updated", flash[:notice]

    alice = users(:alice).reload
    assert_equal "alice2", alice.username
    assert_equal "Alice Two", alice.name
  end

  test "update with blank password keeps the current password" do
    login_as
    digest = users(:alice).password_digest
    patch user_path(users(:alice)), params: {
      user: { username: "alice", name: "Alice Nguyen", password: "", password_confirmation: "" }
    }
    assert_equal digest, users(:alice).reload.password_digest
    assert users(:alice).reload.authenticate("password123")
  end

  test "update with a new password replaces it" do
    login_as
    patch user_path(users(:alice)), params: {
      user: { username: "alice", name: "Alice Nguyen", password: "newpassword", password_confirmation: "newpassword" }
    }
    assert_redirected_to root_path
    assert users(:alice).reload.authenticate("newpassword")
  end

  test "update validation failure re-renders edit" do
    login_as
    patch user_path(users(:alice)), params: {
      user: { username: "", name: "Alice Nguyen", password: "", password_confirmation: "" }
    }
    assert_response :unprocessable_entity
    assert_select "h1", "Edit User"
    assert_equal "alice", users(:alice).reload.username
  end

  test "edit lists the profile's questions" do
    login_as
    get edit_user_path(users(:alice))
    assert_response :success

    profiles(:alice_profile).questions.each do |question|
      assert_select "input[name=?][value=?]", "questions[][text]", question.text
      assert_select "input[name=?][value=?]", "questions[][id]", question.id.to_s
    end
  end

  test "edit offers the converser toggle for a user without a profile" do
    login_as
    get edit_user_path(users(:admin))
    assert_response :success
    assert_select "input[name=?]", "converser"
  end

  test "update edits an existing question in place" do
    login_as
    feeling = questions(:feeling)

    assert_no_difference("Question.count") do
      patch user_path(users(:alice)), params: {
        user: { username: "alice", name: "Alice Nguyen" },
        questions: [
          question_row(feeling, text: "How's your day?", question_type: "select", options: "Good, Bad"),
          question_row(questions(:topic)),
          question_row(questions(:length))
        ]
      }
    end
    assert_redirected_to root_path

    feeling.reload
    assert_equal "How's your day?", feeling.text
    assert_equal "select", feeling.question_type
    assert_equal %w[Good Bad], feeling.options
    assert_equal 1, feeling.position
  end

  test "update adds a question without an id" do
    login_as

    assert_difference("Question.count", 1) do
      patch user_path(users(:alice)), params: {
        user: { username: "alice", name: "Alice Nguyen" },
        questions: [
          question_row(questions(:feeling)),
          question_row(questions(:topic)),
          question_row(questions(:length)),
          question_row(nil, text: "Anything else?", question_type: "text")
        ]
      }
    end

    added = profiles(:alice_profile).questions.ordered.last
    assert_equal "Anything else?", added.text
    assert_equal 4, added.position
  end

  test "update deletes questions left out of the form" do
    login_as

    assert_difference("Question.count", -2) do
      patch user_path(users(:alice)), params: {
        user: { username: "alice", name: "Alice Nguyen" },
        questions: [ question_row(questions(:feeling)) ]
      }
    end
    assert_equal [ questions(:feeling).id ], profiles(:alice_profile).questions.pluck(:id)
  end

  test "update reorders questions to match the submitted order" do
    login_as

    patch user_path(users(:alice)), params: {
      user: { username: "alice", name: "Alice Nguyen" },
      questions: [
        question_row(questions(:length)),
        question_row(questions(:feeling)),
        question_row(questions(:topic))
      ]
    }

    assert_equal [ "Length of chat", "How are you feeling today?", "Preferred topic" ],
                 profiles(:alice_profile).questions.ordered.pluck(:text)
  end

  test "deleting a question keeps its answers with their snapshot" do
    login_as
    answer = answers(:catch_up_feeling)

    assert_no_difference("Answer.count") do
      patch user_path(users(:alice)), params: {
        user: { username: "alice", name: "Alice Nguyen" },
        questions: [ question_row(questions(:topic)), question_row(questions(:length)) ]
      }
    end

    answer.reload
    assert_nil answer.question_id
    assert_equal "How are you feeling today?", answer.question_text
  end

  test "update ignores a question id belonging to another profile" do
    login_as
    stranger = questions(:bob_feeling)

    assert_difference("Question.count", 1) do
      patch user_path(users(:alice)), params: {
        user: { username: "alice", name: "Alice Nguyen" },
        questions: [
          question_row(questions(:feeling)),
          question_row(questions(:topic)),
          question_row(questions(:length)),
          question_row(stranger, text: "Hijacked")
        ]
      }
    end

    assert_equal "What did you do today?", stranger.reload.text
    assert_equal profiles(:alice_profile), profiles(:alice_profile).questions.ordered.last.profile
  end

  test "update makes a user a converser with questions" do
    login_as

    assert_difference("Profile.count", 1) do
      assert_difference("Question.count", 1) do
        patch user_path(users(:admin)), params: {
          user: { username: "admin", name: "Admin" },
          converser: "1",
          questions: [ question_row(nil, text: "New question", question_type: "text") ]
        }
      end
    end

    profile = users(:admin).reload.profile
    assert_equal [ "New question" ], profile.questions.pluck(:text)
  end

  test "update leaves a non-converser alone when the toggle is off" do
    login_as

    assert_no_difference([ "Profile.count", "Question.count" ]) do
      patch user_path(users(:admin)), params: {
        user: { username: "admin", name: "Admin" },
        converser: "0",
        questions: [ question_row(nil, text: "Ignored", question_type: "text") ]
      }
    end
    assert_nil users(:admin).reload.profile
  end

  test "update rolls back question changes when the user is invalid" do
    login_as

    patch user_path(users(:alice)), params: {
      user: { username: "", name: "Alice Nguyen" },
      questions: [ question_row(questions(:feeling), text: "Changed") ]
    }
    assert_response :unprocessable_entity

    assert_equal "How are you feeling today?", questions(:feeling).reload.text
    assert_equal 3, profiles(:alice_profile).questions.count

    # The submitted rows come back so nothing typed is lost.
    assert_select "input[name=?][value=?]", "questions[][text]", "Changed"
  end

  test "update rejects an unknown question type" do
    login_as

    patch user_path(users(:alice)), params: {
      user: { username: "alice", name: "Alice Nguyen" },
      questions: [ question_row(questions(:feeling), question_type: "wat") ]
    }
    assert_response :unprocessable_entity
    assert_equal "text", questions(:feeling).reload.question_type
    assert_equal 3, profiles(:alice_profile).questions.count
  end

  test "validation failure re-renders new" do
    login_as
    assert_no_difference([ "User.count", "Profile.count" ]) do
      post users_path, params: {
        user: {
          username: "",
          name: "No Username",
          password: "password123",
          password_confirmation: "password123"
        },
        converser: "1",
        questions: [ { text: "Q", question_type: "text", options: "" } ]
      }
    end
    assert_response :unprocessable_entity
    assert_select "h1", "Add User"
    assert_select "input[value=?]", "No Username"
  end
end
