require "test_helper"

class DevicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @device = devices(:one)
    @client = @device.client
    @user = users(:one)
    post admin_login_path, params: { email: @user.email, password: "password" }
  end

  test "should get index" do
    get admin_client_devices_path(@client)
    assert_response :success
  end

  test "should get new" do
    get new_admin_client_device_path(@client)
    assert_response :success
  end

  test "should create device" do
    assert_difference("Device.count") do
      post admin_client_devices_path(@client), params: { device: { authentication_expire_at: @device.authentication_expire_at, client_id: @device.client_id, last_ap: @device.last_ap, last_authenticated_at: @device.last_authenticated_at, last_otp: @device.last_otp, mac_address: @device.mac_address, site_id: @device.site_id } }
    end

    assert_redirected_to admin_client_devices_path(@client)
  end

  test "should show device" do
    get admin_client_device_path(@client, @device)
    assert_response :success
  end

  test "should get edit" do
    get edit_admin_client_device_path(@client, @device)
    assert_response :success
  end

  test "should update device" do
    patch admin_client_device_path(@client, @device), params: { device: { authentication_expire_at: @device.authentication_expire_at, client_id: @device.client_id, last_ap: @device.last_ap, last_authenticated_at: @device.last_authenticated_at, last_otp: @device.last_otp, mac_address: @device.mac_address, site_id: @device.site_id } }
    assert_redirected_to admin_client_devices_path(@client)
  end

  test "should destroy device" do
    assert_difference("Device.count", -1) do
      delete admin_client_device_path(@client, @device)
    end

    assert_redirected_to admin_client_devices_path(@client)
  end
end
