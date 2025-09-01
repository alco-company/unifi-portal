require "test_helper"

class DeviceRadiusTest < ActiveSupport::TestCase
  setup do
    @tenant = tenants(:one)
    @tenant.update!(active: true)
    
    @radius_site = Site.create!(
      tenant: @tenant,
      name: 'RADIUS Site',
      controller_type: 'radius',
      ssid: 'radius-test',
      url: '10.0.0.1',
      active: true
    )
    
    @client = Client.create!(
      tenant: @tenant,
      name: 'Test Client',
      email: 'test@example.com',
      phone: '12345678',
      active: true
    )
    
    @device = Device.create!(
      client: @client,
      site: @radius_site,
      mac_address: 'aa:bb:cc:dd:ee:ff',
      active: true
    )
  end

  test "device can enable RADIUS access" do
    assert_not @device.radius_enabled?
    
    # Mock OTP generation and sending
    OtpGenerator.stub(:generate_otp, '123456') do
      OtpMailer.stub(:send_radius_otp, stub_mailer) do
        SmsSender.stub(:send_code, true) do
          result = @device.enable_radius_access!
          
          assert result
          @device.reload
          assert @device.radius_enabled?
          assert_equal @client.email, @device.radius_username
          assert @device.radius_password_hash.present?
          assert_equal '123456', @device.last_otp
          assert @device.otp_expires_at > Time.current
        end
      end
    end
  end

  test "device can disable RADIUS access" do
    @device.update!(
      radius_enabled: true,
      radius_username: @client.email,
      radius_password_hash: 'test_hash',
      device_name: 'Test Device'
    )
    
    @device.disable_radius_access!
    
    @device.reload
    assert_not @device.radius_enabled?
    assert_nil @device.radius_username
    assert_nil @device.radius_password_hash
  end

  test "device generates unique RADIUS username for multiple devices" do
    # Enable RADIUS for first device
    @device.update!(device_name: 'First Device')
    OtpGenerator.stub(:generate_otp, '123456') do
      OtpMailer.stub(:send_radius_otp, stub_mailer) do
        SmsSender.stub(:send_code, true) do
          @device.enable_radius_access!
        end
      end
    end
    
    # Create second device for same client
    device2 = Device.create!(
      client: @client,
      site: @radius_site,
      mac_address: 'bb:cc:dd:ee:ff:aa',
      device_name: 'Second Device',
      active: true
    )
    
    OtpGenerator.stub(:generate_otp, '654321') do
      OtpMailer.stub(:send_radius_otp, stub_mailer) do
        SmsSender.stub(:send_code, true) do
          device2.enable_radius_access!
        end
      end
    end
    
    @device.reload
    device2.reload
    
    # Usernames should be different
    assert_not_equal @device.radius_username, device2.radius_username
    assert_equal @client.email, @device.radius_username
    assert device2.radius_username.include?(@client.email)
    assert device2.radius_username.include?('device')
  end

  test "device authentication with correct OTP succeeds" do
    @device.update!(
      radius_enabled: true,
      radius_username: @client.email,
      last_otp: '123456',
      radius_password_hash: BCrypt::Password.create('123456'),
      otp_expires_at: 10.minutes.from_now,
      device_name: 'Test Device'
    )
    
    OtpGenerator.stub(:generate_otp, '654321') do
      OtpMailer.stub(:send_radius_otp, stub_mailer) do
        SmsSender.stub(:send_code, true) do
          result = @device.radius_authenticate(@client.email, '123456')
          
          assert result[:success]
          assert result[:user_attributes].present?
          assert_match(/Welcome/, result[:user_attributes]['Reply-Message'])
          
          # Should generate new OTP
          @device.reload
          assert_equal '654321', @device.last_otp
          assert_equal 0, @device.radius_auth_failures
        end
      end
    end
  end

  test "device authentication with wrong OTP fails" do
    @device.update!(
      radius_enabled: true,
      radius_username: @client.email,
      last_otp: '123456',
      radius_password_hash: BCrypt::Password.create('123456'),
      otp_expires_at: 10.minutes.from_now,
      device_name: 'Test Device'
    )
    
    result = @device.radius_authenticate(@client.email, 'wrong_otp')
    
    assert_not result[:success]
    assert_equal 'Invalid credentials', result[:error]
    
    @device.reload
    assert_equal 1, @device.radius_auth_failures
  end

  test "device gets locked after 5 failed attempts" do
    @device.update!(
      radius_enabled: true,
      radius_username: @client.email,
      last_otp: '123456',
      radius_password_hash: BCrypt::Password.create('123456'),
      otp_expires_at: 10.minutes.from_now,
      device_name: 'Test Device'
    )
    
    # 5 failed attempts
    5.times do
      @device.radius_authenticate(@client.email, 'wrong_otp')
    end
    
    @device.reload
    assert_equal 5, @device.radius_auth_failures
    assert @device.radius_locked_until.present?
    assert @device.radius_locked_until > Time.current
    
    # Correct OTP should still fail when locked
    result = @device.radius_authenticate(@client.email, '123456')
    assert_not result[:success]
    assert_match(/locked/, result[:error])
  end

  test "device authentication fails with expired OTP" do
    @device.update!(
      radius_enabled: true,
      radius_username: @client.email,
      last_otp: '123456',
      radius_password_hash: BCrypt::Password.create('123456'),
      otp_expires_at: 1.hour.ago,
      device_name: 'Test Device'
    )
    
    result = @device.radius_authenticate(@client.email, '123456')
    
    assert_not result[:success]
    assert_equal 'OTP expired', result[:error]
  end

  test "device authentication fails when RADIUS not enabled" do
    result = @device.radius_authenticate(@client.email, '123456')
    
    assert_not result[:success]
    assert_equal 'RADIUS not enabled', result[:error]
  end

  test "device can only enable RADIUS on RADIUS sites" do
    unifi_site = Site.create!(
      tenant: @tenant,
      name: 'UniFi Site',
      controller_type: 'login',
      ssid: 'unifi-test',
      url: '10.0.0.2',
      active: true
    )
    
    unifi_device = Device.create!(
      client: @client,
      site: unifi_site,
      mac_address: 'cc:dd:ee:ff:aa:bb',
      active: true
    )
    
    result = unifi_device.enable_radius_access!
    assert_not result
    assert_not unifi_device.radius_enabled?
  end

  test "device authorize method routes correctly based on site type" do
    # Test RADIUS site
    OtpGenerator.stub(:generate_otp, '123456') do
      OtpMailer.stub(:send_radius_otp, stub_mailer) do
        SmsSender.stub(:send_code, true) do
          result = @device.authorize
          
          assert result[:success]
          assert_match(/RADIUS access enabled/, result[:message])
          
          @device.reload
          assert @device.radius_enabled?
        end
      end
    end
  end

  test "inactive client cannot enable RADIUS access" do
    @client.update!(active: false)
    
    result = @device.authorize
    
    # Should return false or a hash with success: false
    if result.is_a?(Hash)
      assert_not result[:success]
    else
      assert_not result
    end
  end

  private

  def stub_mailer
    mailer = Object.new
    def mailer.deliver_later; true; end
    mailer
  end
end
