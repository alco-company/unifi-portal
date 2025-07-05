require "test_helper"

class Admin::TenantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_tenant = tenants(:one)
    @user = users(:one)
    post admin_login_path, params: { email: @user.email, password: "password" }
  end

  test "should get index" do
    get admin_tenants_url
    assert_response :success
  end

  test "should get new" do
    get new_admin_tenant_url
    assert_response :success
  end

  test "should create admin_tenant" do
    assert_difference("Tenant.count") do
      post admin_tenants_url, params: { tenant: { active: @admin_tenant.active, name: @admin_tenant.name  } }
    end

    assert_redirected_to admin_tenants_url
  end

  test "should show admin_tenant" do
    get admin_tenant_url(@admin_tenant)
    assert_response :success
  end

  test "should get edit" do
    get edit_admin_tenant_url(@admin_tenant)
    assert_response :success
  end

  test "should update admin_tenant" do
    patch admin_tenant_url(@admin_tenant), params: { tenant: { active: @admin_tenant.active, name: @admin_tenant.name } }
    assert_redirected_to admin_tenants_url
  end

  test "should destroy admin_tenant" do
    assert_difference("Tenant.count", -1) do
      delete admin_tenant_url(@admin_tenant)
    end

    assert_redirected_to admin_tenants_url
  end
end
