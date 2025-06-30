require "application_system_test_case"

class SitesTest < ApplicationSystemTestCase
  setup do
    @site = sites(:one)
  end

  test "visiting the index" do
    visit sites_url
    assert_selector "h1", text: "Sites"
  end

  test "should create site" do
    visit sites_url
    click_on "New site"

    check "Active" if @site.active
    fill_in "Api key", with: @site.api_key
    fill_in "Controller url", with: @site.controller_url
    fill_in "Name", with: @site.name
    fill_in "Ssid", with: @site.ssid
    fill_in "Tenant", with: @site.tenant_id
    fill_in "Url", with: @site.url
    click_on "Create Site"

    assert_text "Site was successfully created"
    click_on "Back"
  end

  test "should update Site" do
    visit site_url(@site)
    click_on "Edit this site", match: :first

    check "Active" if @site.active
    fill_in "Api key", with: @site.api_key
    fill_in "Controller url", with: @site.controller_url
    fill_in "Name", with: @site.name
    fill_in "Ssid", with: @site.ssid
    fill_in "Tenant", with: @site.tenant_id
    fill_in "Url", with: @site.url
    click_on "Update Site"

    assert_text "Site was successfully updated"
    click_on "Back"
  end

  test "should destroy Site" do
    visit site_url(@site)
    accept_confirm { click_on "Destroy this site", match: :first }

    assert_text "Site was successfully destroyed"
  end
end
