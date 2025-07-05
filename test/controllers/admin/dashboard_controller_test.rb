require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    post admin_login_path, params: { email: @user.email, password: "password" }
  end
  test "should get index" do
    get admin_dashboard_index_url
    assert_response :success
  end
end
