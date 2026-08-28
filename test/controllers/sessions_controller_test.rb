require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new renders login form" do
    get login_path
    assert_response :success
    assert_select "h1", "Pleasant Interactions"
  end

  test "login with valid credentials succeeds" do
    post login_path, params: { username: "admin", password: "password123" }
    assert_redirected_to root_path
    assert_equal users(:admin).id, session[:user_id]
    follow_redirect!
    assert_match(/Welcome back/, response.body)
  end

  test "login with invalid credentials fails" do
    post login_path, params: { username: "admin", password: "wrong" }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
    assert_match(/Invalid username or password/, response.body)
  end

  test "login with unknown username fails" do
    post login_path, params: { username: "nobody", password: "password123" }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  test "logout resets session" do
    post login_path, params: { username: "admin", password: "password123" }
    assert_equal users(:admin).id, session[:user_id]

    delete logout_path
    assert_redirected_to login_path
    assert_nil session[:user_id]
  end
end
