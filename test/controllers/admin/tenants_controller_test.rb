require "test_helper"

class Admin::TenantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_tenant = admin_tenants(:one)
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
    assert_difference("Admin::Tenant.count") do
      post admin_tenants_url, params: { admin_tenant: { active: @admin_tenant.active, guest_max: @admin_tenant.guest_max, guest_rx: @admin_tenant.guest_rx, guest_tx: @admin_tenant.guest_tx, login: @admin_tenant.login, name: @admin_tenant.name, password: @admin_tenant.password, url: @admin_tenant.url } }
    end

    assert_redirected_to admin_tenant_url(Admin::Tenant.last)
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
    patch admin_tenant_url(@admin_tenant), params: { admin_tenant: { active: @admin_tenant.active, guest_max: @admin_tenant.guest_max, guest_rx: @admin_tenant.guest_rx, guest_tx: @admin_tenant.guest_tx, login: @admin_tenant.login, name: @admin_tenant.name, password: @admin_tenant.password, url: @admin_tenant.url } }
    assert_redirected_to admin_tenant_url(@admin_tenant)
  end

  test "should destroy admin_tenant" do
    assert_difference("Admin::Tenant.count", -1) do
      delete admin_tenant_url(@admin_tenant)
    end

    assert_redirected_to admin_tenants_url
  end
end
