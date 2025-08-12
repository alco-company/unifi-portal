require "application_system_test_case"

class Admin::NasTest < ApplicationSystemTestCase
  setup do
    @admin_na = admin_nas(:one)
  end

  test "visiting the index" do
    visit admin_nas_url
    assert_selector "h1", text: "Nas"
  end

  test "should create nas" do
    visit admin_nas_url
    click_on "New nas"

    fill_in "Community", with: @admin_na.community
    fill_in "Description", with: @admin_na.description
    fill_in "Nasname", with: @admin_na.nasname
    fill_in "Ports", with: @admin_na.ports
    fill_in "Secret", with: @admin_na.secret
    fill_in "Server", with: @admin_na.server
    fill_in "Shortname", with: @admin_na.shortname
    fill_in "Site", with: @admin_na.site_id
    fill_in "Type", with: @admin_na.type
    click_on "Create Nas"

    assert_text "Nas was successfully created"
    click_on "Back"
  end

  test "should update Nas" do
    visit admin_na_url(@admin_na)
    click_on "Edit this nas", match: :first

    fill_in "Community", with: @admin_na.community
    fill_in "Description", with: @admin_na.description
    fill_in "Nasname", with: @admin_na.nasname
    fill_in "Ports", with: @admin_na.ports
    fill_in "Secret", with: @admin_na.secret
    fill_in "Server", with: @admin_na.server
    fill_in "Shortname", with: @admin_na.shortname
    fill_in "Site", with: @admin_na.site_id
    fill_in "Type", with: @admin_na.type
    click_on "Update Nas"

    assert_text "Nas was successfully updated"
    click_on "Back"
  end

  test "should destroy Nas" do
    visit admin_na_url(@admin_na)
    accept_confirm { click_on "Destroy this nas", match: :first }

    assert_text "Nas was successfully destroyed"
  end
end
