class Device < ApplicationRecord
  belongs_to :client
  belongs_to :site, optional: true
  
  before_save :set_radius_username, if: :radius_enabled?
  
  validates :radius_username, uniqueness: true, allow_nil: true
  validates :device_name, presence: true, if: :radius_enabled?
  validates :mac_address, presence: true, format: { with: /\A([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})\z/, message: "must be a valid MAC address format" }
  validates :mac_address, uniqueness: { scope: :client_id, message: "already exists for this client" }

  def self.authorized?(mac_address)
    device = find_by(mac_address: mac_address)
    return false if device.nil? || device.client.nil? || !device.client.active?
    return false if device.authentication_expire_at.nil? || device.authentication_expire_at < Time.current
    eu = External::Unifi::Base.new(site: device.site)
    return eu.is_mac_authorized?(mac_address) if eu
    false
  end

  def mac_address
    read_attribute(:mac_address).downcase.strip
  rescue
    ""
  end

  def unifi_id
    read_attribute(:unifi_id).presence || mac_address.gsub(/:/, "")
  end

  def unauthorize
    if site.nil?
      return { success: false, error: "No site configured for device" }
    end
    eu = External::Unifi::Base.new(site: site)
    load_client_info(eu)
    result = eu.revoke_guest_access(mac_address)
    
    # Handle case where result is not a hash (e.g., false, nil)
    if result.is_a?(Hash) && result[:success]
      { success: true }
    elsif result.is_a?(Hash)
      result
    else
      { success: false, error: "UniFi revoke access failed" }
    end
  end

  def authorize
    if site.nil?
      return { success: false, error: "No site configured for device" }
    end
    
    if !client.active?
      return { success: false, error: "Client is not active" }
    end
    
    case site.controller_type
    when 'radius'
      authorize_radius_site
    when 'login', 'api_key'
      authorize_unifi_site
    else
      { success: false, error: "Unknown controller type: #{site.controller_type}" }
    end
  end

  def time_limit
    val = authentication_expire_at || created_at
    val > 24.hours.from_now ? 1000000 : 1440
  end

  def load_client_info(eu)
    site_info = eu.site_info
    site.update(unifi_id: eu.get_id) if site_info
    unifi_client_id = eu.get_client_id(mac_address)
    unless unifi_client_id.nil?
      update unifi_id: unifi_client_id
    else
      guests = eu.list_guests.filter { |g| g["mac"] == mac_address }
      if guests.any?
        guests.each do |guest|
          update unifi_id: guest["id"] if guest["id"].present?
        end
        true
      else
        Rails.logger.error("ERROR: Unifi client info not found for MAC address: #{mac_address}")
        false
      end
    end
  end

  def authorize_radius_site
    # For RADIUS sites, enable RADIUS authentication for this device
    enable_radius_access!
    { success: true, message: "RADIUS access enabled. Check your email/SMS for login credentials." }
  end
  
  def authorize_unifi_site
    eu = External::Unifi::Base.new(site: site)
    Rails.logger.error("Authorizing device with MAC address: #{mac_address} for site: #{site.name} using eu: #{eu.inspect}")
    if eu
      load_client_info(eu)
      result = eu.authorize_guest_access(
        mac_address: mac_address,
        minutes: time_limit,
        up: client.guest_tx,
        down: client.guest_rx,
        megabytes: client.guest_max
      )
      
      # Handle case where result is not a hash (e.g., false, nil)
      if result.is_a?(Hash) && result[:success]
        update_client_info(eu, result)
      elsif result.is_a?(Hash)
        result
      else
        { success: false, error: "UniFi authorization failed" }
      end
    else
      { success: false, error: "UniFi connection failed" }
    end
  end
  
  def update_client_info(eu, result)
    Rails.logger.error("Updating device info for MAC address: #{mac_address} with result: #{result.inspect}")
    if result[:data].present?
      data = result[:data]
      update(
        last_ap: data["ap_mac"],
        unifi_id: data["_id"],
        last_authenticated_at: Time.current,
        authentication_expire_at: time_limit.minutes.from_now
      )
    else
      load_client_info(eu)
    end
    Rails.logger.error("Device info updated for MAC address: #{mac_address}")
    { success: true }
  end
  
  # RADIUS Authentication Methods
  
  def enable_radius_access!
    return false unless site&.radius?
    
    # Set device name if not already set
    if device_name.blank?
      self.device_name = "#{client.name || client.email || client.phone}'s device"
    end
    
    generate_new_otp!
    update!(
      radius_enabled: true,
      radius_username: generate_radius_username,
      radius_auth_failures: 0,
      radius_locked_until: nil
    )
  end
  
  def disable_radius_access!
    update!(
      radius_enabled: false,
      radius_username: nil,
      radius_password_hash: nil,
      radius_auth_failures: 0,
      radius_locked_until: nil
    )
  end
  
  def generate_new_otp!
    new_otp = OtpGenerator.generate_otp
    update!(
      last_otp: new_otp,
      otp_expires_at: 15.minutes.from_now,
      radius_password_hash: hash_password(new_otp)
    )
    
    # Send OTP via email/SMS
    send_radius_otp(new_otp)
    new_otp
  end
  
  def radius_authenticate(username, password)
    return { success: false, error: "RADIUS not enabled" } unless radius_enabled?
    return { success: false, error: "Account locked" } if radius_locked?
    return { success: false, error: "Username mismatch" } unless radius_username == username
    return { success: false, error: "OTP expired" } if otp_expired?
    
    if valid_radius_password?(password)
      # Reset failure count and update last auth time
      update!(
        radius_auth_failures: 0,
        radius_last_auth_at: Time.current,
        radius_locked_until: nil
      )
      
      # Generate new OTP for next authentication
      generate_new_otp!
      
      { success: true, user_attributes: radius_user_attributes }
    else
      increment_auth_failures!
      { success: false, error: "Invalid credentials" }
    end
  end
  
  def radius_user_attributes
    {
      "Reply-Message" => "Welcome #{client.name || client.email}",
      "Session-Timeout" => session_timeout,
      "Idle-Timeout" => 3600,
      "Acct-Interim-Interval" => 300,
      "User-Name" => radius_username,
      "Calling-Station-Id" => mac_address&.upcase,
      "Framed-Protocol" => "PPP"
    }
  end
  
  # Check if device can use RADIUS vs UniFi based on site type
  def should_use_radius?
    site&.radius? && client.active?
  end
  
  def should_use_unifi?
    site&.login? || site&.api_key?
  end
  
  # Public methods that tests need access to
  def radius_locked?
    radius_locked_until && radius_locked_until > Time.current
  end
  
  def session_timeout
    # Default 8 hours for RADIUS sessions
    8.hours.to_i
  end
  
  private
  
  def set_radius_username
    return unless radius_enabled?
    self.radius_username ||= generate_radius_username
  end
  
  def generate_radius_username
    # Use email as primary, phone as secondary
    base_username = client.email.presence || client.phone
    return nil unless base_username
    
    # For devices with same client email/phone, append device identifier
    existing_count = Device.where(
      radius_enabled: true,
      client: client
    ).where.not(id: id).count
    
    if existing_count > 0
      "#{base_username}.device#{existing_count + 1}"
    else
      base_username
    end
  end
  
  def hash_password(password)
    BCrypt::Password.create(password)
  end
  
  def valid_radius_password?(password)
    return false unless radius_password_hash
    BCrypt::Password.new(radius_password_hash) == password
  rescue BCrypt::Errors::InvalidHash
    false
  end
  
  def otp_expired?
    otp_expires_at && otp_expires_at < Time.current
  end
  
  def increment_auth_failures!
    new_failure_count = radius_auth_failures + 1
    locked_until = nil
    
    # Lock account after 5 failed attempts for 30 minutes
    if new_failure_count >= 5
      locked_until = 30.minutes.from_now
    end
    
    update!(
      radius_auth_failures: new_failure_count,
      radius_locked_until: locked_until
    )
  end
  
  def send_radius_otp(otp_code)
    begin
      if client.email.present?
        OtpMailer.send_radius_otp(client.email, otp_code, self).deliver_later
      end
      
      if client.phone.present?
        # Use the same method name as the existing SMS sender
        SmsSender.send_code(client.phone, otp_code)
      end
    rescue => e
      Rails.logger.error("Failed to send RADIUS OTP: #{e.message}")
    end
  end
end
