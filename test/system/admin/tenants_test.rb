require "application_system_test_case"

class Admin::TenantsTest < ApplicationSystemTestCase
  setup do
    @admin_tenant = tenants(:one)
    login_as(users(:one))
  end

  test "visiting the index" do
    visit admin_tenants_url
    assert_selector "h1", text: "Tenants"
  end

  test "should create tenant" do
    visit admin_tenants_url
    click_on "New tenant"

    check "Active" if @admin_tenant.active
    fill_in "Username", with: @admin_tenant.username
    fill_in "Name", with: @admin_tenant.name
    fill_in "Password", with: @admin_tenant.password
    click_on "Create Tenant"

    assert_text "Tenant was successfully created"
    assert_selector "h1", text: "Tenants"
  end

  test "should update Tenant" do
    visit admin_tenant_url(@admin_tenant)
    click_on "Edit", match: :first

    check "Active" if @admin_tenant.active
    fill_in "Username", with: @admin_tenant.username
    fill_in "Name", with: @admin_tenant.name
    fill_in "Password", with: @admin_tenant.password
    click_on "Update Tenant"

    assert_text "Tenant was successfully updated"
    assert_selector "h1", text: "Tenants"
  end

  test "should destroy Tenant" do
    visit admin_tenant_url(@admin_tenant)
    click_on "Delete", match: :first
    within("dialog", wait: 3) do
      click_on "Delete"
    end

    assert_text "Tenant was successfully destroyed"
    assert_selector "h1", text: "Tenants"
  end
end
