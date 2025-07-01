require "application_system_test_case"

class Admin::DevicesTest < ApplicationSystemTestCase
  setup do
    @device = devices(:one)
  end

  test "visiting the index" do
    visit admin_client_devices_url(@device.client_id)
    assert_selector "h1", text: "Devices"
  end

  test "should create device" do
    visit admin_client_devices_url(@device.client_id)
    click_on "New device"

    fill_in "Authentication expire at", with: @device.authentication_expire_at
    fill_in "Last ap", with: @device.last_ap
    fill_in "Last authenticated at", with: @device.last_authenticated_at
    fill_in "Last otp", with: @device.last_otp
    fill_in "Mac address", with: @device.mac_address
    click_on "Create Device"

    assert_text "Device was successfully created"
    assert_selector "h1", text: "Devices"
  end

  test "should update Device" do
    visit admin_client_device_url(@device.client_id, @device)
    click_on "Edit", match: :first

    fill_in "Authentication expire at", with: @device.authentication_expire_at.to_s
    fill_in "Last ap", with: @device.last_ap
    fill_in "Last authenticated at", with: @device.last_authenticated_at.to_s
    fill_in "Last otp", with: @device.last_otp
    fill_in "Mac address", with: @device.mac_address
    click_on "Update Device"

    assert_text "Device was successfully updated"
    assert_selector "h1", text: "Devices"
  end

  test "should destroy Device" do
    visit admin_client_device_url(@device.client_id, @device)
    click_on "Delete", match: :first
    within("dialog", wait: 3) do
      click_on "Delete"
    end

    assert_text "Device was successfully destroyed"
    assert_selector "h1", text: "Devices"
  end
end
