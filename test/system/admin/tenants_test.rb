require "application_system_test_case"

class Admin::TenantsTest < ApplicationSystemTestCase
  setup do
    @admin_tenant = admin_tenants(:one)
  end

  test "visiting the index" do
    visit admin_tenants_url
    assert_selector "h1", text: "Tenants"
  end

  test "should create tenant" do
    visit admin_tenants_url
    click_on "New tenant"

    check "Active" if @admin_tenant.active
    fill_in "Guest max", with: @admin_tenant.guest_max
    fill_in "Guest rx", with: @admin_tenant.guest_rx
    fill_in "Guest tx", with: @admin_tenant.guest_tx
    fill_in "Login", with: @admin_tenant.login
    fill_in "Name", with: @admin_tenant.name
    fill_in "Password", with: @admin_tenant.password
    fill_in "Url", with: @admin_tenant.url
    click_on "Create Tenant"

    assert_text "Tenant was successfully created"
    click_on "Back"
  end

  test "should update Tenant" do
    visit admin_tenant_url(@admin_tenant)
    click_on "Edit this tenant", match: :first

    check "Active" if @admin_tenant.active
    fill_in "Guest max", with: @admin_tenant.guest_max
    fill_in "Guest rx", with: @admin_tenant.guest_rx
    fill_in "Guest tx", with: @admin_tenant.guest_tx
    fill_in "Login", with: @admin_tenant.login
    fill_in "Name", with: @admin_tenant.name
    fill_in "Password", with: @admin_tenant.password
    fill_in "Url", with: @admin_tenant.url
    click_on "Update Tenant"

    assert_text "Tenant was successfully updated"
    click_on "Back"
  end

  test "should destroy Tenant" do
    visit admin_tenant_url(@admin_tenant)
    accept_confirm { click_on "Destroy this tenant", match: :first }

    assert_text "Tenant was successfully destroyed"
  end
end
