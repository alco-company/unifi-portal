require "application_system_test_case"

class Admin::NasTest < ApplicationSystemTestCase
  setup do
  @nas = nas(:one)
  @site = @nas.site
  @tenant = @site.tenant
  @user = users(:one)
  # Ensure password matches system test helper expectation
  # users.yml already creates digest from "password"; system helper uses "secret" so override quickly:
  @user.update(password: "secret")
  login_as(@user)
  end

  test "visiting the index" do
  visit admin_tenant_site_nas_index_path(@tenant, @site)
  assert_selector "h1", text: "Nas"
  end

  test "should create nas" do
  visit admin_tenant_site_nas_index_path(@tenant, @site)
    click_on "New nas"

    fill_in "Community", with: @nas.community
    fill_in "Description", with: @nas.description
  fill_in "Nasname", with: "unique-test-nas"
    fill_in "Ports", with: @nas.ports
    fill_in "Secret", with: @nas.secret
    fill_in "Server", with: @nas.server
    fill_in "Shortname", with: @nas.shortname
  fill_in "Type", with: @nas.nas_type
  click_on "Create"

    assert_text "Nas was successfully created"
  click_on "Back"
  end

  test "should update Nas" do
  visit admin_tenant_site_nas_path(@tenant, @site, @nas)
  click_on "Edit", match: :first

    fill_in "Community", with: @nas.community
    fill_in "Description", with: @nas.description
    fill_in "Nasname", with: @nas.nasname
    fill_in "Ports", with: @nas.ports
    fill_in "Secret", with: @nas.secret
    fill_in "Server", with: @nas.server
    fill_in "Shortname", with: @nas.shortname
    fill_in "Type", with: @nas.nas_type
  click_on "Update"

    assert_text "Nas was successfully updated"
  click_on "Back"
  end

  test "should destroy Nas" do
  visit admin_tenant_site_nas_path(@tenant, @site, @nas)
  accept_confirm { click_on "Destroy", match: :first }

    assert_text "Nas was successfully destroyed"
  end
end
