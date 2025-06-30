require "application_system_test_case"

class DevicesTest < ApplicationSystemTestCase
  setup do
    @device = devices(:one)
  end

  test "visiting the index" do
    visit devices_url
    assert_selector "h1", text: "Devices"
  end

  test "should create device" do
    visit devices_url
    click_on "New device"

    fill_in "Authentication expire at", with: @device.authentication_expire_at
    fill_in "Client", with: @device.client_id
    fill_in "Last ap", with: @device.last_ap
    fill_in "Last authenticated at", with: @device.last_authenticated_at
    fill_in "Last otp", with: @device.last_otp
    fill_in "Mac address", with: @device.mac_address
    fill_in "Site", with: @device.site_id
    click_on "Create Device"

    assert_text "Device was successfully created"
    click_on "Back"
  end

  test "should update Device" do
    visit device_url(@device)
    click_on "Edit this device", match: :first

    fill_in "Authentication expire at", with: @device.authentication_expire_at.to_s
    fill_in "Client", with: @device.client_id
    fill_in "Last ap", with: @device.last_ap
    fill_in "Last authenticated at", with: @device.last_authenticated_at.to_s
    fill_in "Last otp", with: @device.last_otp
    fill_in "Mac address", with: @device.mac_address
    fill_in "Site", with: @device.site_id
    click_on "Update Device"

    assert_text "Device was successfully updated"
    click_on "Back"
  end

  test "should destroy Device" do
    visit device_url(@device)
    accept_confirm { click_on "Destroy this device", match: :first }

    assert_text "Device was successfully destroyed"
  end
end
