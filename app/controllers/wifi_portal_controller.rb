class WifiPortalController < ApplicationController
  layout "guest"
  skip_before_action :verify_authenticity_token, only: [ :verify_phone, :verify_email ]

  # GET /wifi
  def index
    # Landing page for WiFi self-service portal
    # Users can verify their identity via phone or email
    slug = params[:site].to_s
    site = Site.find_by(slug: slug) || nil
    session[:site_id] = site.id if site
  end

  # GET /wifi/setup/:token
  def setup
    @client = find_client_by_token
    return render_error("Invalid or expired link") unless @client

    @radius_devices = @client.devices.joins(:site).where(sites: { controller_type: "radius" })
    @has_radius_sites = @radius_devices.any?
  end

  # t.boolean "active", default: true
  # t.datetime "created_at", null: false
  # t.string "email"
  # t.integer "guest_max", default: 0
  # t.integer "guest_rx", default: 0
  # t.integer "guest_tx", default: 0
  # t.string "name"
  # t.text "note"
  # t.string "phone"
  # t.bigint "tenant_id", null: false
  #
  # POST /wifi/verify_phone
  def verify_phone
    phone = params[:phone]&.gsub(/\D/, "")

    if phone.present? && phone.length >= 8
      @client = build_client(phone: phone)

      if @client&.active?
        send_verification_otp(@client, :phone)
        session[:wifi_client_id] = @client.id
        session[:verification_method] = "phone"

        render json: {
          success: true,
          message: "Verification code sent to your phone",
          next_step: "otp_verification"
        }
      else
        render json: {
          success: false,
          message: "Phone number not found or account inactive"
        }
      end
    else
      render json: {
        success: false,
        message: "Please enter a valid phone number"
      }
    end
  end

  # POST /wifi/verify_email
  def verify_email
    email = params[:email]&.downcase&.strip


    if email.present? && email.match?(URI::MailTo::EMAIL_REGEXP)
      @client = build_client(email: email)

      if @client
        send_verification_otp(@client, :email)
        session[:wifi_client_id] = @client.id
        session[:verification_method] = "email"

        render json: {
          success: true,
          message: "Verification code sent to your email",
          next_step: "otp_verification"
        }
      else
        render json: {
          success: false,
          message: "Email not found or account inactive"
        }
      end
    else
      render json: {
        success: false,
        message: "Please enter a valid email address"
      }
    end
  end

  # POST /wifi/verify_otp
  def verify_otp
    client_id = session[:wifi_client_id]
    otp = params[:otp]

    @client = Client.find_by(id: client_id, active: true) if client_id

    unless @client
      render json: { success: false, message: "Session expired. Please start over." }
      return
    end

    if verify_client_otp(@client, otp)
      session[:verified_client_id] = @client.id
      session.delete(:wifi_client_id)

      render json: {
        success: true,
        message: "Verification successful",
        redirect_url: wifi_dashboard_path(site: session[:site_id])
      }
    else
      render json: {
        success: false,
        message: "Invalid verification code"
      }
    end
  end

  # GET /wifi/dashboard
  def dashboard
    @client = find_verified_client
    @site = find_verified_site
    return redirect_to wifi_portal_path, alert: "Please verify your identity first" unless @client && @site

    @radius_devices = @client.devices.joins(:site).where(sites: { controller_type: "radius" })
    @unifi_devices = @client.devices.joins(:site).where(sites: { controller_type: [ "login", "api_key" ] })
    if @site.radius? && @radius_devices.empty?
      @radius_devices = build_device
    end
  end

  # POST /wifi/enable_device_radius
  def enable_device_radius
    @client = find_verified_client
    return render json: { success: false, message: "Unauthorized" } unless @client

    device = @client.devices.find_by(id: params[:device_id])
    device_name = params[:device_name].present? ? params[:device_name] : "My Device"

    if device&.site&.radius?
      device.update!(device_name: device_name, radius_username: @client.email || @client.phone)

      if device.enable_radius_access!
        render json: {
          success: true,
          message: "WiFi access enabled! Check your #{session[:verification_method]} for login credentials.",
          username: device.radius_username,
          expires_at: device.otp_expires_at&.strftime("%H:%M")
        }
      else
        render json: {
          success: false,
          message: "Failed to enable WiFi access"
        }
      end
    else
      render json: {
        success: false,
        message: "Device is not on a RADIUS-enabled network"
      }
    end
  end

  # POST /wifi/regenerate_otp
  def regenerate_otp
    @client = find_verified_client
    return render json: { success: false, message: "Unauthorized" } unless @client

    device = @client.devices.find_by(id: params[:device_id])

    if device&.radius_enabled?
      device.generate_new_otp!

      render json: {
        success: true,
        message: "New login code sent to your #{session[:verification_method]}!",
        expires_at: device.otp_expires_at&.strftime("%H:%M")
      }
    else
      render json: {
        success: false,
        message: "WiFi access is not enabled for this device"
      }
    end
  end

  # POST /wifi/disable_device_radius
  def disable_device_radius
    @client = find_verified_client
    return render json: { success: false, message: "Unauthorized" } unless @client

    device = @client.devices.find_by(id: params[:device_id])

    if device&.radius_enabled?
      device.disable_radius_access!
      render json: { success: true, message: "WiFi access disabled for this device" }
    else
      render json: { success: false, message: "WiFi access was not enabled" }
    end
  end

  # GET /wifi/instructions/:device_id
  def instructions
    @client = find_verified_client
    return redirect_to wifi_portal_path, alert: "Please verify your identity first" unless @client

    @device = @client.devices.find_by(id: params[:device_id])
    return redirect_to wifi_dashboard_path, alert: "Device not found" unless @device

    unless @device.radius_enabled?
      redirect_to wifi_dashboard_path, alert: "WiFi access is not enabled for this device"
    end
  end

  private

  def find_client_by_token
    # This could be enhanced with proper token-based access
    # For now, we'll use session-based verification
    nil
  end

  def find_verified_client
    client_id = session[:verified_client_id]
    Client.find_by(id: client_id, active: true) if client_id
  end

  def find_verified_site
    site_id = session[:site_id]
    Site.find_by(id: site_id) if site_id
  end

  def send_verification_otp(client, method)
    otp = OtpGenerator.generate_otp
    session[:verification_otp] = otp
    session[:verification_expires] = 10.minutes.from_now

    case method
    when :phone
      SmsSender.send_code(client.phone, otp) if client.phone.present?
    when :email
      OtpMailer.send_otp(client.email, otp).deliver_now if client.email.present?
    end
  end

  def verify_client_otp(client, otp)
    stored_otp = session[:verification_otp]
    expires_at = session[:verification_expires]

    return false unless stored_otp && expires_at
    return false if Time.current > expires_at
    return false unless stored_otp == otp

    session.delete(:verification_otp)
    session.delete(:verification_expires)
    true
  end

  # Escape per Wi‑Fi QR spec (escape \ ; , :)
  def esc(str)
    return "" if str.blank?
    str.to_s.gsub("\\", "\\\\").gsub(";", "\\;").gsub(",", "\\,").gsub(":", "\\:")
  end

  def wifi_payload(ssid:, key:, auth:, hidden:)
    "WIFI:T:#{auth};S:#{esc(ssid)};P:#{esc(key)};H:#{hidden ? 'true' : 'false'};;"
  end

  def build_client(site: nil, phone: nil, email: nil)
    client = Client.find_by("REGEXP_REPLACE(phone, '[^0-9]', '') = ?", phone) unless phone.nil?
    client = Client.find_by(email: email, active: true) unless email.nil?
    site = session[:site_id]

    unless client
      client = Client.create active: true,
        email: phone,
        phone: phone,
        tenant_id: site&.tenant_id,
        guest_max: 0,
        guest_rx: 0,
        guest_tx: 0,
        name: "Guest User(#{phone || email})"
    end
    client
  end

  def build_device
    aea = (@client.created_at < Time.current - 8.hours) ? Time.current + 3.years : 1.day.from_now
    device = @client.devices.create site_id: @site.id,
      authentication_expire_at: aea,
      radius_enabled: true,
      device_name: "Device-#{SecureRandom.hex(4)}",
      mac_address: request.remote_ip
    unless device.valid?
      if device.errors.full_messages.filter { |m| m =~ /Mac/ }.count > 0
        device.update!(mac_address: "00:0C:00:00:00:01")
      end
    end
    [ device ]
  end
end
