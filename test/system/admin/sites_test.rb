require "application_system_test_case"

class Admin::SitesTest < ApplicationSystemTestCase
  setup do
    @site = sites(:one)
  end

  test "visiting the index" do
    visit admin_tenant_sites_url(@site.tenant_id)
    assert_selector "h1", text: "Sites"
  end

  test "should create site" do
    visit admin_tenant_sites_url(@site.tenant_id)
    click_on "New site"

    check "Active" if @site.active
    fill_in "Api key", with: @site.api_key
    fill_in "Controller url", with: @site.controller_url
    fill_in "Name", with: @site.name
    fill_in "Ssid", with: @site.ssid
    fill_in "Url", with: @site.url
    click_on "Create Site"

    assert_text "Site was successfully created"
    assert_selector "h1", text: "Sites"
  end

  test "should update Site" do
    visit admin_tenant_site_url(@site.tenant_id, @site)
    click_on "Edit this site", match: :first

    check "Active" if @site.active
    fill_in "Api key", with: @site.api_key
    fill_in "Controller url", with: @site.controller_url
    fill_in "Name", with: @site.name
    fill_in "Ssid", with: @site.ssid
    fill_in "Url", with: @site.url
    click_on "Update Site"

    assert_text "Site was successfully updated"
    assert_selector "h1", text: "Sites"
  end

  test "should destroy Site" do
    visit admin_tenant_site_url(@site.tenant_id, @site)
    click_on "Delete", match: :first
    within("dialog", wait: 3) do
      click_on "Delete"
    end

    assert_text "Site was successfully destroyed"
    assert_selector "h1", text: "Sites"

  end
end
