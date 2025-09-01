require "test_helper"

class RadiusApiIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    # Stub SMS API to prevent external calls during RADIUS setup
    WebMock.stub_request(:post, "https://api.smsapi.com/sms.do")
      .to_return(status: 200, body: '{"count":1,"list":[{"id":"test","status":"QUEUE"}]}', headers: {})
    @tenant = tenants(:one)
    @tenant.update!(active: true)
    
    # Create RADIUS site with NAS
    @radius_site = Site.create!(
      tenant: @tenant,
      name: 'radius-network',
      active: true,
      controller_type: 'radius',
      ssid: 'radius-test',
      url: '10.0.0.1',
      controller_url: 'https://radius.example.com'
    )
    
    @nas = Nas.create!(
      site: @radius_site,
      nasname: '10.0.0.100',
      shortname: 'test-nas',
      description: 'Test NAS',
      secret: 'testing123'
    )
    
    # Create client with RADIUS-enabled device
    @client = Client.create!(
      tenant: @tenant,
      name: 'Test Client',
      email: 'test@example.com',
      phone: '12345678',
      active: true,
      guest_max: 1000,
      guest_rx: 5000,
      guest_tx: 10000
    )
    
    @device = Device.create!(
      client: @client,
      site: @radius_site,
      mac_address: 'aa:bb:cc:dd:ee:ff',
      device_name: 'Test Device',
      active: true
    )
    
    # Enable RADIUS for device
    @device.enable_radius_access!
    
    # Create inactive client for negative tests
    @inactive_client = Client.create!(
      tenant: @tenant,
      name: 'Inactive Client',
      email: 'inactive@example.com',
      phone: '87654321',
      active: false
    )
    
    @inactive_device = Device.create!(
      client: @inactive_client,
      site: @radius_site,
      mac_address: 'ff:ff:ff:ff:ff:ff',
      device_name: 'Inactive Test Device',
      radius_enabled: true,
      radius_username: @inactive_client.email,
      radius_password_hash: BCrypt::Password.create('test_otp'),
      active: true
    )
  end

  # Authentication endpoint tests
  
  test "successful RADIUS authentication" do
    post api_radius_authenticate_path, params: {
      username: @device.radius_username,
      password: @device.last_otp,
      nas_ip: @nas.nasname,
      calling_station_id: @device.mac_address.upcase.gsub(':', '-')
    }
    
    assert_response :ok
    response_json = JSON.parse(response.body)
    
    assert response_json['success']
    assert_equal @device.radius_username, response_json['username']
    assert_equal 'device_otp', response_json['method']
    assert_equal @tenant.name, response_json['tenant']
    
    # Check reply attributes
    attributes = response_json['reply_attributes']
    assert attributes.present?
    assert attributes['Session-Timeout'].present?
    assert attributes['User-Name'] == @device.radius_username
    assert_match(/Welcome/, attributes['Reply-Message'])
    
    # Verify device state changed
    @device.reload
    assert @device.radius_last_auth_at > 1.minute.ago
    assert_equal 0, @device.radius_auth_failures
    assert_nil @device.radius_locked_until
  end
  
  test "authentication with wrong password fails" do
    post api_radius_authenticate_path, params: {
      username: @device.radius_username,
      password: 'wrong_password',
      nas_ip: @nas.nasname,
      calling_station_id: @device.mac_address.upcase.gsub(':', '-')
    }
    
    assert_response :unauthorized
    response_json = JSON.parse(response.body)
    
    assert_not response_json['success']
    assert_equal @device.radius_username, response_json['username']
    assert_match(/Invalid credentials/, response_json['reason'])
    
    # Verify failure count increased
    @device.reload
    assert_equal 1, @device.radius_auth_failures
  end
  
  test "authentication with expired OTP fails" do
    # Expire the OTP
    @device.update!(otp_expires_at: 1.hour.ago)
    
    post api_radius_authenticate_path, params: {
      username: @device.radius_username,
      password: @device.last_otp,
      nas_ip: @nas.nasname,
      calling_station_id: @device.mac_address.upcase.gsub(':', '-')
    }
    
    assert_response :unauthorized
    response_json = JSON.parse(response.body)
    
    assert_not response_json['success']
    assert_match(/OTP expired/, response_json['reason'])
  end
  
  test "authentication with locked account fails" do
    # Lock the account
    @device.update!(
      radius_auth_failures: 5,
      radius_locked_until: 1.hour.from_now
    )
    
    post api_radius_authenticate_path, params: {
      username: @device.radius_username,
      password: @device.last_otp,
      nas_ip: @nas.nasname,
      calling_station_id: @device.mac_address.upcase.gsub(':', '-')
    }
    
    assert_response :unauthorized
    response_json = JSON.parse(response.body)
    
    assert_not response_json['success']
    assert_match(/locked/, response_json['reason'])
  end
  
  test "authentication from unauthorized NAS fails" do
    post api_radius_authenticate_path, params: {
      username: @device.radius_username,
      password: @device.last_otp,
      nas_ip: '192.168.1.100', # Not authorized
      calling_station_id: @device.mac_address.upcase.gsub(':', '-')
    }
    
    assert_response :unauthorized
    response_json = JSON.parse(response.body)
    
    assert_not response_json['success']
    assert_match(/Unauthorized network access point/, response_json['reason'])
  end
  
  test "authentication for nonexistent user fails" do
    post api_radius_authenticate_path, params: {
      username: 'nonexistent@example.com',
      password: 'any_password',
      nas_ip: @nas.nasname,
      calling_station_id: 'AA-BB-CC-DD-EE-FF'
    }
    
    assert_response :unauthorized
    response_json = JSON.parse(response.body)
    
    assert_not response_json['success']
    assert_match(/not found/, response_json['reason'])
  end
  
  test "authentication with missing username fails" do
    post api_radius_authenticate_path, params: {
      password: @device.last_otp,
      nas_ip: @nas.nasname
    }
    
    assert_response :bad_request
    response_json = JSON.parse(response.body)
    
    assert_not response_json['success']
    assert_match(/Username is required/, response_json['error'])
  end
  
  test "authentication with missing password fails" do
    post api_radius_authenticate_path, params: {
      username: @device.radius_username,
      nas_ip: @nas.nasname
    }
    
    assert_response :bad_request
    response_json = JSON.parse(response.body)
    
    assert_not response_json['success']
    assert_match(/Password is required/, response_json['error'])
  end
  
  # Authorization endpoint tests
  
  test "successful RADIUS authorization" do
    post api_radius_authorize_path, params: {
      username: @device.radius_username,
      nas_ip: @nas.nasname,
      calling_station_id: @device.mac_address.upcase.gsub(':', '-')
    }
    
    assert_response :ok
    response_json = JSON.parse(response.body)
    
    assert response_json['success']
    assert_equal @device.radius_username, response_json['username']
    assert_equal 'radius_device', response_json['user_type']
    assert_equal @tenant.name, response_json['tenant']
    
    # Check reply attributes
    attributes = response_json['reply_attributes']
    assert attributes.present?
    assert attributes['Session-Timeout'].present?
    assert attributes['User-Name'] == @device.radius_username
  end
  
  test "authorization for inactive client fails" do
    post api_radius_authorize_path, params: {
      username: @inactive_device.radius_username,
      nas_ip: @nas.nasname,
      calling_station_id: @inactive_device.mac_address.upcase.gsub(':', '-')
    }
    
    assert_response :not_found
    response_json = JSON.parse(response.body)
    
    assert_not response_json['success']
    assert_match(/not found/, response_json['reason'])
  end
  
  # Accounting endpoint tests
  
  test "accounting start record" do
    post api_radius_accounting_path, params: {
      username: @device.radius_username,
      acct_status_type: 'start',
      acct_session_id: 'test_session_123',
      nas_ip: @nas.nasname,
      calling_station_id: @device.mac_address.upcase.gsub(':', '-')
    }
    
    assert_response :ok
    response_json = JSON.parse(response.body)
    assert response_json['success']
  end
  
  test "accounting stop record" do
    post api_radius_accounting_path, params: {
      username: @device.radius_username,
      acct_status_type: 'stop',
      acct_session_id: 'test_session_123',
      acct_session_time: '3600',
      nas_ip: @nas.nasname,
      calling_station_id: @device.mac_address.upcase.gsub(':', '-')
    }
    
    assert_response :ok
    response_json = JSON.parse(response.body)
    assert response_json['success']
  end
  
  test "accounting interim update record" do
    post api_radius_accounting_path, params: {
      username: @device.radius_username,
      acct_status_type: 'interim-update',
      acct_session_id: 'test_session_123',
      acct_input_octets: '1024000',
      acct_output_octets: '2048000',
      nas_ip: @nas.nasname,
      calling_station_id: @device.mac_address.upcase.gsub(':', '-')
    }
    
    assert_response :ok
    response_json = JSON.parse(response.body)
    assert response_json['success']
  end
  
  # Status endpoint tests
  
  test "status endpoint returns system information" do
    get api_radius_status_path
    
    assert_response :ok
    response_json = JSON.parse(response.body)
    
    assert response_json['radius_enabled']
    assert response_json['database_connected']
    assert response_json['active_users'].present?
    assert response_json['timestamp'].present?
    
    active_users = response_json['active_users']
    assert active_users['active_clients'].is_a?(Integer)
    assert active_users['active_devices'].is_a?(Integer)
    assert active_users['radius_enabled_devices'].is_a?(Integer)
  end
  
  # Integration flow tests
  
  test "complete authentication flow with OTP regeneration" do
    original_otp = @device.last_otp
    
    # Successful authentication should generate new OTP
    post api_radius_authenticate_path, params: {
      username: @device.radius_username,
      password: original_otp,
      nas_ip: @nas.nasname,
      calling_station_id: @device.mac_address.upcase.gsub(':', '-')
    }
    
    assert_response :ok
    response_json = JSON.parse(response.body)
    assert response_json['success']
    
    # Verify new OTP was generated
    @device.reload
    assert_not_equal original_otp, @device.last_otp
    assert @device.otp_expires_at > Time.current
    
    # Old OTP should no longer work
    post api_radius_authenticate_path, params: {
      username: @device.radius_username,
      password: original_otp,
      nas_ip: @nas.nasname,
      calling_station_id: @device.mac_address.upcase.gsub(':', '-')
    }
    
    assert_response :unauthorized
    response_json = JSON.parse(response.body)
    assert_not response_json['success']
  end
  
  test "progressive lockout after multiple failed attempts" do
    username = @device.radius_username
    nas_ip = @nas.nasname
    calling_station = @device.mac_address.upcase.gsub(':', '-')
    
    # First 4 failures should not lock the account
    4.times do |i|
      post api_radius_authenticate_path, params: {
        username: username,
        password: "wrong_password_#{i}",
        nas_ip: nas_ip,
        calling_station_id: calling_station
      }
      
      assert_response :unauthorized
      response_json = JSON.parse(response.body)
      assert_not response_json['success']
      
      @device.reload
      assert_equal i + 1, @device.radius_auth_failures
      assert_nil @device.radius_locked_until
    end
    
    # 5th failure should lock the account
    post api_radius_authenticate_path, params: {
      username: username,
      password: "wrong_password_5",
      nas_ip: nas_ip,
      calling_station_id: calling_station
    }
    
    assert_response :unauthorized
    response_json = JSON.parse(response.body)
    assert_not response_json['success']
    
    @device.reload
    assert_equal 5, @device.radius_auth_failures
    assert @device.radius_locked_until.present?
    assert @device.radius_locked_until > Time.current
    
    # Correct password should also fail when locked
    post api_radius_authenticate_path, params: {
      username: username,
      password: @device.last_otp,
      nas_ip: nas_ip,
      calling_station_id: calling_station
    }
    
    assert_response :unauthorized
    response_json = JSON.parse(response.body)
    assert_not response_json['success']
    assert_match(/locked/, response_json['reason'])
  end
  
  # Username format tests
  
  test "authentication works with email username" do
    email_device = Device.create!(
      client: @client,
      site: @radius_site,
      mac_address: 'bb:cc:dd:ee:ff:aa',
      device_name: 'Email Device',
      active: true
    )
    email_device.enable_radius_access!
    
    # Second device for same client gets suffix
    assert_equal "#{@client.email}.device2", email_device.radius_username
    
    post api_radius_authenticate_path, params: {
      username: email_device.radius_username,
      password: email_device.last_otp,
      nas_ip: @nas.nasname,
      calling_station_id: email_device.mac_address.upcase.gsub(':', '-')
    }
    
    assert_response :ok
    response_json = JSON.parse(response.body)
    assert response_json['success']
  end
  
  test "authentication works with phone username for client without email" do
    phone_client = Client.create!(
      tenant: @tenant,
      name: 'Phone Client',
      phone: '99887766',
      active: true
    )
    
    phone_device = Device.create!(
      client: phone_client,
      site: @radius_site,
      mac_address: 'cc:dd:ee:ff:aa:bb',
      device_name: 'Phone Device',
      active: true
    )
    phone_device.enable_radius_access!
    
    assert_equal phone_client.phone, phone_device.radius_username
    
    post api_radius_authenticate_path, params: {
      username: phone_device.radius_username,
      password: phone_device.last_otp,
      nas_ip: @nas.nasname,
      calling_station_id: phone_device.mac_address.upcase.gsub(':', '-')
    }
    
    assert_response :ok
    response_json = JSON.parse(response.body)
    assert response_json['success']
  end
  
  test "multiple devices for same client get unique usernames" do
    # Create second device for same client
    device2 = Device.create!(
      client: @client,
      site: @radius_site,
      mac_address: 'dd:ee:ff:aa:bb:cc',
      device_name: 'Second Device',
      active: true
    )
    device2.enable_radius_access!
    
    # Usernames should be different
    assert_not_equal @device.radius_username, device2.radius_username
    assert device2.radius_username.include?(@client.email)
    assert device2.radius_username.include?('device')
    
    # Both should authenticate successfully
    [@device, device2].each do |device|
      post api_radius_authenticate_path, params: {
        username: device.radius_username,
        password: device.last_otp,
        nas_ip: @nas.nasname,
        calling_station_id: device.mac_address.upcase.gsub(':', '-')
      }
      
      assert_response :ok
      response_json = JSON.parse(response.body)
      assert response_json['success']
    end
  end
end
