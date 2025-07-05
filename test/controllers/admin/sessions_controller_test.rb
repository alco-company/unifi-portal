require "test_helper"

class Admin::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get admin_login_url
    assert_response :success
  end

  test "should get create" do
    get admin_login_url
    assert_response :success
  end

  test "should get destroy" do
    delete admin_logout_url
    assert_redirected_to admin_login_url
  end
end
