require "test_helper"

class Admin::DevicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @device = devices(:one)
    @client = @device.client
    @tenant = @client.tenant
    @site = @device.site
    login_as users(:one)
  end

  # Basic CRUD operations
  test "should get index" do
    get admin_client_devices_path(@client)
    assert_response :success
    assert_includes response.body, @device.mac_address
  end

  test "should get index with search query" do
    get admin_client_devices_path(@client), params: { query: @device.mac_address[0..5] }
    assert_response :success
    assert_includes response.body, @device.mac_address
  end

  test "should get new" do
    get new_admin_client_device_path(@client)
    assert_response :success
    assert_select "form[action=?]", admin_client_devices_path(@client)
    assert_select "input[name='device[mac_address]']"
  end

  test "should create device with valid parameters" do
    device_params = {
      mac_address: "aa:bb:cc:dd:ee:ff",
      site_id: @site.id,
      last_ap: "ap01.example.com"
    }
    
    assert_difference("Device.count") do
      post admin_client_devices_path(@client), params: { device: device_params }
    end
    
    assert_redirected_to admin_client_devices_path(@client)
    
    created_device = Device.find_by(mac_address: "aa:bb:cc:dd:ee:ff")
    assert_not_nil created_device
    assert_equal @client.id, created_device.client_id
    assert_equal @site.id, created_device.site_id
  end

  test "should not create device with invalid mac address" do
    device_params = {
      mac_address: "invalid-mac",
      site_id: @site.id
    }
    
    assert_no_difference("Device.count") do
      post admin_client_devices_path(@client), params: { device: device_params }
    end
    
    # Response depends on model validation - might be success with errors or unprocessable_entity
    assert_response :unprocessable_entity
  end

  test "should show device" do
    get admin_client_device_path(@client, @device)
    assert_response :success
    assert_includes response.body, @device.mac_address
    assert_includes response.body, @device.last_ap if @device.last_ap.present?
  end

  test "should get edit" do
    get edit_admin_client_device_path(@client, @device)
    assert_response :success
    assert_select "form[action=?]", admin_client_device_path(@client, @device)
    assert_select "input[value=?]", @device.mac_address
  end

  test "should update device with valid parameters" do
    new_ap = "updated-ap.example.com"
    
    patch admin_client_device_path(@client, @device), params: {
      device: {
        last_ap: new_ap,
        mac_address: @device.mac_address,
        site_id: @device.site_id
      }
    }
    
    assert_redirected_to admin_client_devices_path(@client)
    
    @device.reload
    assert_equal new_ap, @device.last_ap
  end

  test "should destroy device" do
    assert_difference("Device.count", -1) do
      delete admin_client_device_path(@client, @device)
    end
    
    assert_redirected_to admin_client_devices_path(@client)
    assert_not Device.exists?(@device.id)
  end

  test "should handle non-existent device gracefully" do
    delete admin_client_device_path(@client, 99999)
    assert_redirected_to admin_client_devices_path(@client)
  end

  # Bulk operations
  test "should delete all devices" do
    # Create additional devices for the client
    device2 = Device.create!(
      client: @client,
      mac_address: "11:22:33:44:55:66",
      site: @site
    )
    device3 = Device.create!(
      client: @client,
      mac_address: "77:88:99:aa:bb:cc",
      site: @site
    )
    
    initial_count = @client.devices.count
    assert initial_count >= 3 # Original device + 2 new ones
    
    delete delete_all_admin_client_devices_path(@client)
    
    assert_redirected_to admin_client_devices_path(@client)
    assert_equal 0, @client.devices.count
  end

  # RADIUS functionality tests
  test "should create RADIUS-enabled device" do
    device_params = {
      mac_address: "cc:dd:ee:ff:11:22",
      site_id: @site.id,
      device_name: "New RADIUS Device",
      radius_enabled: true
    }
    
    assert_difference("Device.count") do
      post admin_client_devices_path(@client), params: { device: device_params }
    end
    
    created_device = Device.find_by(mac_address: "cc:dd:ee:ff:11:22")
    assert_not_nil created_device
    assert_equal "New RADIUS Device", created_device.device_name
    # Check if RADIUS fields are supported by the controller params
    if created_device.respond_to?(:radius_enabled?)
      assert created_device.radius_enabled?
    end
  end

  test "should display device with RADIUS capabilities" do
    # Create a RADIUS-enabled device
    radius_device = Device.create!(
      client: @client,
      mac_address: "aa:bb:cc:dd:ee:ff",
      site: @site,
      device_name: "Test RADIUS Device",
      radius_enabled: true,
      radius_username: "test_radius_user",
      active: true
    )
    
    get admin_client_devices_path(@client)
    assert_response :success
    
    # Should show both regular and RADIUS devices
    assert_includes response.body, @device.mac_address
    assert_includes response.body, radius_device.mac_address
  end

  # Authentication tests
  test "should require authentication for index" do
    # Reset session to simulate logged out user
    reset!
    
    get admin_client_devices_path(@client)
    assert_redirected_to admin_login_path
  end

  test "should require authentication for create" do
    reset!
    
    post admin_client_devices_path(@client), params: { device: { mac_address: "aa:bb:cc:dd:ee:ff" } }
    assert_redirected_to admin_login_path
  end

  test "should require authentication for destroy" do
    reset!
    
    delete admin_client_device_path(@client, @device)
    assert_redirected_to admin_login_path
  end

  # Edge cases
  test "should handle special characters in device names" do
    special_name = "Device with émojis 🚀 and special chars @#$%"
    
    device_params = {
      mac_address: "aa:bb:cc:dd:ee:f2",
      site_id: @site.id,
      device_name: special_name
    }
    
    assert_difference("Device.count") do
      post admin_client_devices_path(@client), params: { device: device_params }
    end
    
    created_device = Device.find_by(mac_address: "aa:bb:cc:dd:ee:f2")
    assert_equal special_name, created_device.device_name
  end

  # JSON API tests
  test "should respond to JSON for index" do
    get admin_client_devices_path(@client), as: :json
    assert_response :success
    assert_equal "application/json", response.media_type
  end

  test "should create device via JSON API" do
    device_params = {
      mac_address: "aa:bb:cc:dd:ee:f4",
      site_id: @site.id
    }
    
    assert_difference("Device.count") do
      post admin_client_devices_path(@client), 
           params: { device: device_params },
           as: :json
    end
    
    assert_response :created
    assert_equal "application/json", response.media_type
  end
end
