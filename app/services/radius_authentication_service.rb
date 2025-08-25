# app/services/radius_authentication_service.rb

class RadiusAuthenticationService
  include ActiveSupport::Benchmarkable

  attr_reader :username, :password, :nas_ip, :calling_station_id

  def initialize(username:, password:, nas_ip: nil, calling_station_id: nil)
    @username = username.to_s.strip
    @password = password.to_s
    @nas_ip = nas_ip
    @calling_station_id = calling_station_id&.downcase&.gsub(/[^0-9a-f:]/, '')
  end

  # Main authentication method - returns hash with auth result
  def authenticate
    benchmark "RADIUS Authentication for #{username}" do
      Rails.logger.info "RADIUS auth attempt: #{username} from NAS #{nas_ip}"
      
      # Try multiple authentication methods
      auth_result = try_phone_authentication ||
                   try_email_authentication ||
                   try_admin_user_authentication ||
                   try_device_mac_authentication

      if auth_result[:success]
        log_successful_auth(auth_result)
        Rails.logger.info "RADIUS auth SUCCESS: #{username} (method: #{auth_result[:method]})"
      else
        log_failed_auth(auth_result[:reason])
        Rails.logger.warn "RADIUS auth FAILED: #{username} - #{auth_result[:reason]}"
      end

      auth_result
    end
  end

  # Create or update RADIUS database entries for a user
  def self.provision_radius_user(username:, password:, session_timeout: 86400, nas_client: nil)
    username = username.to_s.strip
    
    # Create/update radcheck entry
    existing_check = find_or_create_radcheck(username)
    existing_check.update!(
      attribute: 'Cleartext-Password',
      op: ':=',
      value: password
    )

    # Create/update radreply entry for session timeout  
    existing_reply = find_or_create_radreply(username)
    existing_reply.update!(
      attribute: 'Session-Timeout',
      op: '=',
      value: session_timeout.to_s
    )

    # Create NAS client if provided
    if nas_client
      create_nas_client(nas_client)
    end

    Rails.logger.info "RADIUS user provisioned: #{username}"
    { success: true, username: username }
  rescue => e
    Rails.logger.error "RADIUS provisioning failed: #{e.message}"
    { success: false, error: e.message }
  end

  # Remove RADIUS database entries for a user
  def self.deprovision_radius_user(username:)
    username = username.to_s.strip
    
    Radius::Radcheck.where(username: username).destroy_all
    ActiveRecord::Base.connection.execute(
      "DELETE FROM radreply WHERE username = #{ActiveRecord::Base.connection.quote(username)}"
    )
    ActiveRecord::Base.connection.execute(
      "DELETE FROM radpostauth WHERE username = #{ActiveRecord::Base.connection.quote(username)}"
    )

    Rails.logger.info "RADIUS user deprovisioned: #{username}"
    { success: true }
  rescue => e
    Rails.logger.error "RADIUS deprovisioning failed: #{e.message}"
    { success: false, error: e.message }
  end

  private

  # Try authentication using phone number (for clients/guests)
  def try_phone_authentication
    # Normalize phone number - remove non-digits
    normalized_phone = username.gsub(/\D/, '')
    return nil if normalized_phone.empty?

    client = Client.joins(:tenant)
                  .where("REGEXP_REPLACE(phone, '[^0-9]', '') = ?", normalized_phone)
                  .where(active: true)
                  .where(tenants: { active: true })
                  .first

    return nil unless client

    # Check if this client has any active devices
    active_device = client.devices.where(active: true)
                          .where('authentication_expire_at IS NULL OR authentication_expire_at > ?', Time.current)
                          .first

    # For phone authentication, we'll accept a simple password or OTP
    if valid_client_password?(client, password) || valid_device_otp?(active_device, password)
      session_timeout = calculate_session_timeout(active_device)
      
      {
        success: true,
        method: 'phone',
        client: client,
        device: active_device,
        session_timeout: session_timeout,
        tenant: client.tenant
      }
    end
  end

  # Try authentication using email (for clients or admin users)  
  def try_email_authentication
    return nil unless username.include?('@')

    # Try client email first
    client = Client.joins(:tenant)
                  .where(email: username, active: true)
                  .where(tenants: { active: true })
                  .first

    if client
      active_device = client.devices.where(active: true)
                            .where('authentication_expire_at IS NULL OR authentication_expire_at > ?', Time.current)
                            .first

      if valid_client_password?(client, password) || valid_device_otp?(active_device, password)
        session_timeout = calculate_session_timeout(active_device)
        
        return {
          success: true,
          method: 'email_client',
          client: client,
          device: active_device,
          session_timeout: session_timeout,
          tenant: client.tenant
        }
      end
    end

    nil
  end

  # Try authentication using admin user credentials
  def try_admin_user_authentication
    return nil unless username.include?('@')

    user = User.joins(:tenant)
              .where(email: username, active: true)
              .where(tenants: { active: true })
              .first

    return nil unless user

    if user.authenticate(password)
      {
        success: true,
        method: 'admin_user',
        user: user,
        session_timeout: 86400, # 24 hours for admin users
        tenant: user.tenant
      }
    end
  end

  # Try authentication using MAC address (for device-based auth)
  def try_device_mac_authentication
    return nil unless calling_station_id

    # Normalize MAC address
    mac = calling_station_id.gsub(/[^0-9a-f]/, '').scan(/.{2}/).join(':')
    
    device = Device.joins(client: :tenant)
                   .where(mac_address: mac, active: true)
                   .where(clients: { active: true })
                   .where(tenants: { active: true })
                   .where('authentication_expire_at IS NULL OR authentication_expire_at > ?', Time.current)
                   .first

    return nil unless device

    # For MAC-based auth, check if device is authorized or use a device password
    if device.last_otp == password || valid_device_password?(device, password)
      session_timeout = calculate_session_timeout(device)
      
      {
        success: true,
        method: 'device_mac',
        device: device,
        client: device.client,
        session_timeout: session_timeout,
        tenant: device.client.tenant
      }
    end
  end

  # Validate password for client (could be temporary password or OTP)
  def valid_client_password?(client, password)
    return false unless client

    # Check if there's a device with matching OTP
    client.devices.where(last_otp: password, active: true).exists? ||
    # Or check for a simple validation (customize as needed)
    password == "guest123" ||  # Default guest password
    password == client.phone&.last(4)  # Last 4 digits of phone
  end

  # Validate OTP for specific device
  def valid_device_otp?(device, password)
    return false unless device
    device.last_otp == password && 
    device.last_authenticated_at && 
    device.last_authenticated_at > 1.hour.ago
  end

  # Validate password for device (device-specific authentication)
  def valid_device_password?(device, password)
    return false unless device
    
    # Device-specific password could be based on MAC address
    mac_password = device.mac_address.gsub(':', '').last(6)
    password == mac_password || password == device.last_otp
  end

  # Calculate session timeout based on device/client settings
  def calculate_session_timeout(device)
    return 86400 unless device  # Default 24 hours

    if device.authentication_expire_at
      remaining_time = [(device.authentication_expire_at - Time.current).to_i, 300].max
      [remaining_time, 86400].min  # Max 24 hours
    else
      86400  # Default 24 hours
    end
  end

  # Log successful authentication
  def log_successful_auth(result)
    log_entry = {
      username: username,
      method: result[:method],
      nas_ip: nas_ip,
      calling_station_id: calling_station_id,
      session_timeout: result[:session_timeout],
      tenant: result[:tenant]&.name,
      timestamp: Time.current
    }

    Rails.logger.info "RADIUS_SUCCESS: #{log_entry.to_json}"
    
    # Update last authentication time if we have a device
    if result[:device]
      result[:device].update(last_authenticated_at: Time.current)
    end
  end

  # Log failed authentication  
  def log_failed_auth(reason)
    log_entry = {
      username: username,
      nas_ip: nas_ip,
      calling_station_id: calling_station_id,
      reason: reason,
      timestamp: Time.current
    }

    Rails.logger.warn "RADIUS_FAILURE: #{log_entry.to_json}"
  end

  # Helper methods for database operations

  def self.find_or_create_radcheck(username)
    begin
      Radius::Radcheck.find_or_create_by(username: username) do |record|
        record.attribute = 'Cleartext-Password'
        record.op = ':='
        record.value = 'temp'
      end
    rescue => e
      # Fallback to raw SQL if model doesn't work
      ActiveRecord::Base.connection.execute(%{
        INSERT IGNORE INTO radcheck (username, attribute, op, value) 
        VALUES (#{ActiveRecord::Base.connection.quote(username)}, 'Cleartext-Password', ':=', 'temp')
      })
      Radius::Radcheck.find_by(username: username)
    end
  end

  def self.find_or_create_radreply(username)
    begin
      # Use raw SQL since we might not have a Radreply model
      ActiveRecord::Base.connection.execute(%{
        INSERT IGNORE INTO radreply (username, attribute, op, value) 
        VALUES (#{ActiveRecord::Base.connection.quote(username)}, 'Session-Timeout', '=', '86400')
      })
      
      # Return a simple object that responds to update!
      OpenStruct.new(
        username: username,
        update!: ->(attrs) {
          ActiveRecord::Base.connection.execute(%{
            UPDATE radreply 
            SET attribute = #{ActiveRecord::Base.connection.quote(attrs[:attribute])},
                op = #{ActiveRecord::Base.connection.quote(attrs[:op])},
                value = #{ActiveRecord::Base.connection.quote(attrs[:value])}
            WHERE username = #{ActiveRecord::Base.connection.quote(username)}
          })
        }
      )
    rescue => e
      Rails.logger.error "Error with radreply: #{e.message}"
      raise e
    end
  end

  def self.create_nas_client(nas_config)
    site = Site.find_by(id: nas_config[:site_id]) if nas_config[:site_id]
    return unless site

    site.nas.find_or_create_by(nasname: nas_config[:nasname]) do |nas|
      nas.shortname = nas_config[:shortname] || nas_config[:nasname]
      nas.nas_type = nas_config[:nas_type] || 'other'
      nas.secret = nas_config[:secret] || 'testing123'
      nas.description = nas_config[:description] || 'Auto-created NAS'
    end
  end
end
