require "test_helper"

class Api::RadiusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = tenants(:one)
    @tenant.update!(active: true)  # Ensure tenant is active for legacy lookups
    @site = sites(:one)
    @client = clients(:one)
    @client.update!(active: true)  # Ensure client is active
    @device = devices(:one)
    
    # Create a RADIUS-enabled device for testing
    @radius_device = Device.create!(
      client: @client,
      mac_address: "00:11:22:33:44:55",
      device_name: "RADIUS Test Device",
      radius_enabled: true,
      radius_username: "radius_user",
      radius_password_hash: BCrypt::Password.create("test_password"),
      active: true
    )
    
    # Create NAS for testing
    @nas = Nas.create!(
      site: @site,
      nasname: "192.168.1.1",
      shortname: "test-nas",
      secret: "test-secret",
      nas_type: "cisco"
    )
    
    # Common RADIUS request headers
    @radius_headers = {
      'Content-Type' => 'application/json',
      'User-Agent' => 'FreeRADIUS-CURL/1.0'
    }
  end

  # Basic endpoint availability tests
  test "authentication endpoint requires username" do
    post '/api/radius/authenticate', params: {
      password: 'test_password',
      nas_ip: '192.168.1.1'
    }, headers: @radius_headers, as: :json
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    
    assert_equal false, json_response['success']
    assert_equal 'Username is required', json_response['error']
  end

  test "authentication endpoint requires password" do
    post '/api/radius/authenticate', params: {
      username: 'radius_user',
      nas_ip: '192.168.1.1'
    }, headers: @radius_headers, as: :json
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    
    assert_equal false, json_response['success']
    assert_equal 'Password is required for authentication', json_response['error']
  end

  test "authorization endpoint requires username" do
    post '/api/radius/authorize', params: {
      nas_ip: '192.168.1.1'
    }, headers: @radius_headers, as: :json
    
    assert_response :bad_request
    json_response = JSON.parse(response.body)
    
    assert_equal false, json_response['success']
    assert_equal 'Username is required', json_response['error']
  end

  test "successful radius device authorization" do
    post '/api/radius/authorize', params: {
      username: 'radius_user',
      nas_ip: '192.168.1.1',
      calling_station_id: '00-11-22-33-44-55'
    }, headers: @radius_headers, as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal true, json_response['success']
    assert_equal 'radius_user', json_response['username']
    assert_equal 'radius_device', json_response['user_type']
    assert_equal @client.tenant.name, json_response['tenant']
    assert_not_nil json_response['reply_attributes']
  end

  test "authorization failure for inactive client" do
    @client.update!(active: false)
    
    post '/api/radius/authorize', params: {
      username: 'radius_user',
      nas_ip: '192.168.1.1'
    }, headers: @radius_headers, as: :json
    
    assert_response :not_found
    json_response = JSON.parse(response.body)
    
    assert_equal false, json_response['success']
    assert_equal 'User not found or inactive', json_response['reason']
  end

  test "fallback to legacy user lookup by phone" do
    # Remove radius device
    @radius_device.destroy!
    
    # Create client with phone number
    phone_client = Client.create!(
      tenant: @tenant,
      name: "Phone User",
      phone: "+1-555-123-4567",
      email: "phone@example.com",
      active: true
    )
    
    phone_device = Device.create!(
      client: phone_client,
      mac_address: "aa:bb:cc:dd:ee:ff",
      device_name: "Phone Device",
      active: true
    )
    
    post '/api/radius/authorize', params: {
      username: '15551234567',  # Normalized phone number
      nas_ip: '192.168.1.1'
    }, headers: @radius_headers, as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal true, json_response['success']
    assert_equal '15551234567', json_response['username']
    assert_equal 'client', json_response['user_type']
    assert_equal phone_client.tenant.name, json_response['tenant']
    assert_not_nil json_response['reply_attributes']['Session-Timeout']
  end

  test "fallback to legacy user lookup by email" do
    @radius_device.destroy!
    
    post '/api/radius/authorize', params: {
      username: @client.email,
      nas_ip: '192.168.1.1'
    }, headers: @radius_headers, as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal true, json_response['success']
    assert_equal @client.email, json_response['username']
    assert_equal 'client_email', json_response['user_type']
  end

  test "device lookup by mac address" do
    @radius_device.destroy!
    
    post '/api/radius/authorize', params: {
      username: 'unknown_user',
      nas_ip: '192.168.1.1',
      calling_station_id: @device.mac_address
    }, headers: @radius_headers, as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal true, json_response['success']
    assert_equal 'device_mac', json_response['user_type']
  end

  test "accounting endpoint accepts start records" do
    post '/api/radius/accounting', params: {
      username: 'test_user',
      acct_status_type: 'Start',
      acct_session_id: 'session123',
      nas_ip: '192.168.1.1',
      calling_station_id: '00-11-22-33-44-55'
    }, headers: @radius_headers, as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal true, json_response['success']
  end

  test "accounting endpoint accepts stop records" do
    post '/api/radius/accounting', params: {
      username: 'test_user',
      acct_status_type: 'Stop',
      acct_session_id: 'session123',
      acct_session_time: '3600',
      nas_ip: '192.168.1.1'
    }, headers: @radius_headers, as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal true, json_response['success']
  end

  test "accounting endpoint accepts update records" do
    post '/api/radius/accounting', params: {
      username: 'test_user',
      acct_status_type: 'Interim-Update',
      acct_session_id: 'session123',
      acct_input_octets: '1048576',
      acct_output_octets: '2097152',
      nas_ip: '192.168.1.1'
    }, headers: @radius_headers, as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal true, json_response['success']
  end

  test "accounting endpoint handles unknown status types" do
    post '/api/radius/accounting', params: {
      username: 'test_user',
      acct_status_type: 'unknown_type',
      acct_session_id: 'session123',
      nas_ip: '192.168.1.1'
    }, headers: @radius_headers, as: :json
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal true, json_response['success']
  end

  test "status endpoint returns system information" do
    get '/api/radius/status', headers: @radius_headers
    
    assert_response :success
    json_response = JSON.parse(response.body)
    
    assert_equal true, json_response['radius_enabled']
    assert_not_nil json_response['database_connected']
    assert_not_nil json_response['freeradius_tables']
    assert_not_nil json_response['active_users']
    assert_not_nil json_response['timestamp']
  end

  test "authentication failure when no radius device found and no fallback" do
    # Remove radius device
    @radius_device.destroy!
    
    post '/api/radius/authenticate', params: {
      username: 'unknown_user',
      password: 'password',
      nas_ip: '192.168.1.1'
    }, headers: @radius_headers, as: :json
    
    assert_response :unauthorized
    json_response = JSON.parse(response.body)
    
    assert_equal false, json_response['success']
    assert_equal 'User not found', json_response['reason']
  end
end
