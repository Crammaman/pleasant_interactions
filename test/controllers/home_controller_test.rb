require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not logged in" do
    get root_path
    assert_redirected_to login_path
  end

  test "lists profile names and interaction counts when logged in" do
    post login_path, params: { username: "admin", password: "password123" }

    get root_path
    assert_response :success

    assert_select "h1", "Profiles"

    # Profile display names (the profile's user's name).
    assert_match(/Alice Nguyen/, response.body)
    assert_match(/Bob Marsh/, response.body)

    # Alice has two interactions (catch_up, weekly_chat); Bob has one (bob_chat).
    assert_match(/2 interactions/, response.body)
    assert_match(/1 interaction/, response.body)

    # Link to each profile's current queue.
    assert_select "a[href=?]", queue_profile_path(profiles(:alice_profile))
    assert_select "a[href=?]", queue_profile_path(profiles(:bob_profile))

    # Each card footer links to editing that profile's user.
    assert_select "a[href=?]", edit_user_path(users(:alice))
    assert_select "a[href=?]", edit_user_path(users(:bob))
  end
end
