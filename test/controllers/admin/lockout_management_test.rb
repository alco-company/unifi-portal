require "test_helper"

class Admin::LockoutManagementTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = tenants(:one)
    @tenant.update!(active: true)
    @user = users(:one)
    
    # Stub external services
    stub_external_services
    
    # Create RADIUS site
    @radius_site = Site.create!(
      tenant: @tenant,
      name: 'radius-network',
      active: true,
      controller_type: 'radius',
      ssid: 'radius-test',
      url: '10.0.0.1',
      controller_url: 'https://radius.example.com'
    )
    
    # Create UniFi site
    @unifi_site = sites(:one)
    @unifi_site.update!(
      active: true,
      controller_type: 'login',
      ssid: 'unifi-test',
      url: '10.0.0.2'
    )
    
    # Create client with devices
    @client = clients(:one)
    @client.update!(
      active: true,
      name: 'Test Client',
      email: 'test@example.com',
      phone: '12345678'
    )
    
    # Create devices
    @radius_device = Device.create!(
      client: @client,
      site: @radius_site,
      mac_address: 'aa:bb:cc:dd:ee:ff',
      radius_enabled: true,
      radius_username: @client.email,
      radius_password_hash: BCrypt::Password.create('test_otp'),
      device_name: 'Test RADIUS Device',
      active: true
    )
    
    @unifi_device = Device.create!(
      client: @client,
      site: @unifi_site,
      mac_address: 'ff:ee:dd:cc:bb:aa',
      active: true
    )
    
    # Login as admin
    post admin_login_path, params: { email: @user.email, password: "secret" }
  end

  # Client-level lockout tests
  
  test "admin can lock out client from network access" do
    # Verify client is initially active
    assert @client.active?
    
    # Admin locks client
    patch admin_tenant_client_path(@tenant, @client), params: {
      client: { active: false }
    }
    
    assert_redirected_to admin_tenant_clients_path(@tenant)
    
    @client.reload
    assert_not @client.active?
    
    # Verify devices can't authorize
    @client.devices.each do |device|
      result = device.authorize
      assert_not result[:success] if result.is_a?(Hash)
    end
  end
  
  test "admin can unlock client to restore network access" do
    # Lock client first
    @client.update!(active: false)
    
    # Verify devices can't authorize
    result = @radius_device.authorize
    assert_not result[:success]
    
    # Admin unlocks client
    patch admin_tenant_client_path(@tenant, @client), params: {
      client: { active: true }
    }
    
    @client.reload
    assert @client.active?
    
    # Verify RADIUS device can now get access
    result = @radius_device.authorize
    assert result[:success]
  end
  
  # RADIUS device-level lockout tests
  
  test "admin can view RADIUS devices list" do
    get admin_tenant_radius_devices_path(@tenant)
    assert_response :success
    
    assert_select "body", text: /#{@radius_device.device_name}/
    assert_select "body", text: /#{@radius_device.radius_username}/
    assert_select "body", text: /#{@radius_device.client.name}/
  end
  
  test "admin can view individual RADIUS device details" do
    get admin_tenant_radius_device_path(@tenant, @radius_device)
    assert_response :success
    
    assert_select "body", text: /#{@radius_device.device_name}/
    assert_select "body", text: /#{@radius_device.radius_username}/
    assert_select "body", text: /#{@radius_device.client.email}/
  end
  
  test "admin can enable RADIUS for device" do
    # Create device without RADIUS
    device = Device.create!(
      client: @client,
      site: @radius_site,
      mac_address: '11:22:33:44:55:66',
      active: true
    )
    
    assert_not device.radius_enabled?
    
    # Admin enables RADIUS with stubbed external services
    OtpGenerator.stub :generate_otp, '123456' do
      SmsSender.stub :send_code, true do
        mock_mailer = Minitest::Mock.new
        mock_mailer.expect :deliver_later, true
        OtpMailer.stub :send_radius_otp, mock_mailer do
          post enable_radius_admin_tenant_radius_device_path(@tenant, device), params: {
            device_name: 'New RADIUS Device'
          }
        end
      end
    end
    
    assert_redirected_to admin_tenant_radius_device_path(@tenant, device)
    
    device.reload
    assert device.radius_enabled?
    assert_equal 'New RADIUS Device', device.device_name
    assert device.radius_username.present?
    assert device.radius_password_hash.present?
  end
  
  test "admin can disable RADIUS for device" do
    assert @radius_device.radius_enabled?
    
    delete disable_radius_admin_tenant_radius_device_path(@tenant, @radius_device)
    
    assert_redirected_to admin_tenant_radius_device_path(@tenant, @radius_device)
    
    @radius_device.reload
    assert_not @radius_device.radius_enabled?
    assert_nil @radius_device.radius_username
    assert_nil @radius_device.radius_password_hash
  end
  
  test "admin can regenerate OTP for RADIUS device" do
    old_otp = @radius_device.last_otp
    old_hash = @radius_device.radius_password_hash
    
    # Admin regenerates OTP with stubbed external services
    OtpGenerator.stub :generate_otp, '654321' do
      SmsSender.stub :send_code, true do
        mock_mailer = Minitest::Mock.new
        mock_mailer.expect :deliver_later, true
        OtpMailer.stub :send_radius_otp, mock_mailer do
          post regenerate_otp_admin_tenant_radius_device_path(@tenant, @radius_device)
        end
      end
    end
    
    assert_redirected_to admin_tenant_radius_device_path(@tenant, @radius_device)
    
    @radius_device.reload
    assert_not_equal old_otp, @radius_device.last_otp
    assert_not_equal old_hash, @radius_device.radius_password_hash
    assert @radius_device.otp_expires_at > Time.current
  end
  
  test "admin can reset authentication failures" do
    # Lock device with failures
    @radius_device.update!(
      radius_auth_failures: 5,
      radius_locked_until: 1.hour.from_now
    )
    
    assert @radius_device.radius_locked?
    
    # Admin resets failures
    post reset_failures_admin_tenant_radius_device_path(@tenant, @radius_device)
    
    assert_redirected_to admin_tenant_radius_device_path(@tenant, @radius_device)
    
    @radius_device.reload
    assert_equal 0, @radius_device.radius_auth_failures
    assert_nil @radius_device.radius_locked_until
    assert_not @radius_device.radius_locked?
  end
  
  test "admin can bulk enable RADIUS for multiple devices" do
    # Create additional devices without RADIUS
    device2 = Device.create!(
      client: @client,
      site: @radius_site,
      mac_address: '22:33:44:55:66:77',
      device_name: 'Device 2',
      active: true
    )
    
    device3 = Device.create!(
      client: @client,
      site: @radius_site,
      mac_address: '33:44:55:66:77:88',
      device_name: 'Device 3',
      active: true
    )
    
    assert_not device2.radius_enabled?
    assert_not device3.radius_enabled?
    
    # Bulk enable with stubbed external services
    OtpGenerator.stub :generate_otp, '789012' do
      SmsSender.stub :send_code, true do
        mock_mailer = Minitest::Mock.new
        mock_mailer.expect :deliver_later, true
        mock_mailer.expect :deliver_later, true  # Two devices
        OtpMailer.stub :send_radius_otp, mock_mailer do
          post bulk_enable_admin_tenant_radius_devices_path(@tenant), params: {
            device_ids: [device2.id, device3.id]
          }
        end
      end
    end
    
    assert_redirected_to admin_tenant_radius_devices_path(@tenant)
    
    device2.reload
    device3.reload
    
    assert device2.radius_enabled?
    assert device3.radius_enabled?
    assert device2.radius_username.present?
    assert device3.radius_username.present?
  end
  
  test "admin can bulk disable RADIUS for multiple devices" do
    # Create additional RADIUS-enabled device
    device2 = Device.create!(
      client: @client,
      site: @radius_site,
      mac_address: '22:33:44:55:66:77',
      device_name: 'RADIUS Device 2',
      radius_enabled: true,
      radius_username: 'test2@example.com',
      radius_password_hash: BCrypt::Password.create('test'),
      active: true
    )
    
    assert @radius_device.radius_enabled?
    assert device2.radius_enabled?
    
    # Bulk disable
    post bulk_disable_admin_tenant_radius_devices_path(@tenant), params: {
      device_ids: [@radius_device.id, device2.id]
    }
    
    assert_redirected_to admin_tenant_radius_devices_path(@tenant)
    
    @radius_device.reload
    device2.reload
    
    assert_not @radius_device.radius_enabled?
    assert_not device2.radius_enabled?
  end
  
  # Integration tests for lockout effects
  
  test "locked client devices cannot authenticate via RADIUS API" do
    # Lock the client
    @client.update!(active: false)
    
    # Try RADIUS authentication
    post api_radius_authenticate_path, params: {
      username: @radius_device.radius_username,
      password: 'test_otp',
      nas_ip: '10.0.0.1'
    }
    
    assert_response :unauthorized
    response_json = JSON.parse(response.body)
    assert_not response_json['success']
    assert_match(/not found/, response_json['reason'])
  end
  
  test "RADIUS-disabled device cannot authenticate" do
    # Disable RADIUS for device
    @radius_device.update!(radius_enabled: false)
    
    # Try RADIUS authentication
    post api_radius_authenticate_path, params: {
      username: @radius_device.radius_username,
      password: 'test_otp',
      nas_ip: '10.0.0.1'
    }
    
    assert_response :unauthorized
    response_json = JSON.parse(response.body)
    assert_not response_json['success']
    assert_match(/not found/, response_json['reason'])
  end
  
  test "locked RADIUS device cannot authenticate even with correct password" do
    # Lock device
    @radius_device.update!(
      radius_auth_failures: 5,
      radius_locked_until: 1.hour.from_now
    )
    
    # Try authentication with correct OTP
    result = @radius_device.radius_authenticate(@radius_device.radius_username, @radius_device.last_otp)
    
    assert_not result[:success]
    assert_match(/locked/, result[:error])
  end
  
  # Search and filtering tests
  
  test "admin can search RADIUS devices by client name" do
    get admin_tenant_radius_devices_path(@tenant), params: { search: @client.name }
    assert_response :success
    assert_select "body", text: /#{@radius_device.device_name}/
  end
  
  test "admin can search RADIUS devices by email" do
    get admin_tenant_radius_devices_path(@tenant), params: { search: @client.email }
    assert_response :success
    assert_select "body", text: /#{@radius_device.device_name}/
  end
  
  test "admin can search RADIUS devices by MAC address" do
    get admin_tenant_radius_devices_path(@tenant), params: { search: @radius_device.mac_address }
    assert_response :success
    assert_select "body", text: /#{@radius_device.device_name}/
  end
  
  # Error handling tests
  
  test "enabling RADIUS on non-RADIUS site fails" do
    unifi_device = Device.create!(
      client: @client,
      site: @unifi_site,
      mac_address: '99:88:77:66:55:44',
      active: true
    )
    
    post enable_radius_admin_tenant_radius_device_path(@tenant, unifi_device), params: {
      device_name: 'Should Fail'
    }
    
    assert_redirected_to admin_tenant_radius_device_path(@tenant, unifi_device)
    assert_match(/not configured for RADIUS/, flash[:alert])
    
    unifi_device.reload
    assert_not unifi_device.radius_enabled?
  end
  
  test "regenerating OTP for non-RADIUS device fails" do
    post regenerate_otp_admin_tenant_radius_device_path(@tenant, @unifi_device)
    
    assert_redirected_to admin_tenant_radius_device_path(@tenant, @unifi_device)
    assert_match(/not enabled/, flash[:alert])
  end
  
  private
  
  def stub_external_services
    # Stub SMS API calls
    stub_request(:post, "https://api.smsapi.com/sms.do")
      .with(
        body: /to=.*&message=.*&from=.*&format=json/,
        headers: {
          'Accept' => '*/*',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authorization' => /Bearer .*/,
          'User-Agent' => 'Ruby'
        })
      .to_return(status: 200, body: '{"success":true}', headers: {})
    
    # Stub UniFi API calls  
    stub_request(:get, "https://heimdall.test/api/self/sites")
      .with(
        headers: {
          'Accept' => 'application/json',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type' => 'application/json',
          'Cookie' => 'test_cookie',
          'User-Agent' => 'Ruby'
        })
      .to_return(status: 200, body: '{"data":[]}', headers: {})
    
    # Stub UniFi proxy API calls
    stub_request(:get, "https://radius.example.com/proxy/network/integration/v1/sites")
      .with(
        headers: {
          'Accept' => 'application/json',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type' => 'application/json',
          'User-Agent' => 'Ruby'
        })
      .to_return(status: 200, body: '{"data":[]}', headers: {})
    
    # Stub client search API calls
    stub_request(:get, /https:\/\/radius\.example\.com\/proxy\/network\/integration\/v1\/sites\/.*\/clients\?filter=.*/) 
      .with(
        headers: {
          'Accept' => 'application/json',
          'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type' => 'application/json',
          'User-Agent' => 'Ruby'
        })
      .to_return(status: 200, body: '{"data":[]}', headers: {})
    
    # Stub UniFi authorization calls
    stub_request(:post, /.*\/api\/s\/.*\/cmd\/stamgr/)
      .to_return(status: 200, body: '{"data":[{"_id":"test123"}], "meta":{"rc":"ok"}}', headers: {})
    
    # Stub UniFi client status calls
    stub_request(:get, /.*\/api\/s\/.*\/stat\/sta\/.*/).
      to_return(status: 200, body: '{"data":[{"_id":"test123","mac":"1c:71:25:63:e4:24"}], "meta":{"rc":"ok"}}', headers: {})
    
    # Stub UniFi guests list calls
    stub_request(:get, /.*\/api\/s\/.*\/stat\/guest.*/).
      to_return(status: 200, body: '{"data":[{"_id":"test123","mac":"ff:ee:dd:cc:bb:aa"}], "meta":{"rc":"ok"}}', headers: {})
    
    # Mock OTP generation to return a consistent value
    OtpGenerator.stub :generate_otp, '123456' do
      # Mock SmsSender to not actually send SMS  
      SmsSender.stub :send_code, true do
        # Mock OtpMailer to not actually send emails
        mock_mailer = Minitest::Mock.new
        mock_mailer.expect :deliver_later, true
        OtpMailer.stub :send_radius_otp, mock_mailer do
          yield if block_given?
        end
      end
    end
  end
end
