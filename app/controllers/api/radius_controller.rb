# app/controllers/api/radius_controller.rb

class Api::RadiusController < ApplicationController
  # Skip CSRF protection for RADIUS API calls
  skip_before_action :verify_authenticity_token
  
  # Skip any authentication - we'll handle RADIUS-specific auth
  # skip_before_action :authenticate_user! if defined?(authenticate_user!)
  
  before_action :validate_radius_request
  before_action :log_radius_request

  # POST /api/radius/authenticate
  # FreeRADIUS calls this endpoint to authenticate users
  def authenticate
    auth_service = RadiusAuthenticationService.new(
      username: params[:username],
      password: params[:password], 
      nas_ip: params[:nas_ip] || request.remote_ip,
      calling_station_id: params[:calling_station_id]
    )

    auth_result = auth_service.authenticate

    if auth_result[:success]
      render json: {
        success: true,
        username: params[:username],
        session_timeout: auth_result[:session_timeout],
        method: auth_result[:method],
        tenant: auth_result[:tenant]&.name,
        reply_attributes: build_reply_attributes(auth_result)
      }, status: 200
    else
      render json: {
        success: false,
        username: params[:username],
        reason: auth_result[:reason] || 'Authentication failed'
      }, status: 401
    end
  rescue => e
    Rails.logger.error "RADIUS API Error: #{e.message}\n#{e.backtrace.join("\n")}"
    render json: {
      success: false,
      error: 'Internal server error'
    }, status: 500
  end

  # POST /api/radius/authorize  
  # FreeRADIUS calls this for authorization checks
  def authorize
    username = params[:username]
    nas_ip = params[:nas_ip] || request.remote_ip
    calling_station_id = params[:calling_station_id]

    # Basic authorization - check if user exists and is active
    auth_service = RadiusAuthenticationService.new(
      username: username,
      password: 'dummy', # Not used for authorization
      nas_ip: nas_ip,
      calling_station_id: calling_station_id
    )

    # Get user/device info without password verification
    user_info = find_user_info(username, calling_station_id)

    if user_info[:found]
      render json: {
        success: true,
        username: username,
        user_type: user_info[:type],
        tenant: user_info[:tenant]&.name,
        reply_attributes: {
          'Session-Timeout' => user_info[:session_timeout] || 86400
        }
      }, status: 200
    else
      render json: {
        success: false,
        username: username,
        reason: 'User not found or inactive'
      }, status: 404
    end
  rescue => e
    Rails.logger.error "RADIUS Authorization Error: #{e.message}"
    render json: {
      success: false,
      error: 'Authorization error'
    }, status: 500
  end

  # POST /api/radius/accounting
  # FreeRADIUS calls this for accounting (start/stop/update)
  def accounting
    username = params[:username]
    acct_status_type = params[:acct_status_type]&.downcase
    session_id = params[:acct_session_id]
    nas_ip = params[:nas_ip] || request.remote_ip
    
    Rails.logger.info "RADIUS Accounting: #{username} - #{acct_status_type} (session: #{session_id})"

    case acct_status_type
    when 'start'
      handle_accounting_start
    when 'stop' 
      handle_accounting_stop
    when 'update', 'interim-update'
      handle_accounting_update
    else
      Rails.logger.warn "Unknown accounting status: #{acct_status_type}"
    end

    render json: { success: true }, status: 200
  rescue => e
    Rails.logger.error "RADIUS Accounting Error: #{e.message}"
    render json: { success: false, error: 'Accounting error' }, status: 500
  end

  # GET /api/radius/status
  # Health check endpoint for RADIUS integration
  def status
    status_info = {
      radius_enabled: true,
      database_connected: database_connected?,
      freeradius_tables: check_freeradius_tables,
      active_users: get_active_user_counts,
      timestamp: Time.current.iso8601
    }

    render json: status_info, status: 200
  rescue => e
    Rails.logger.error "RADIUS Status Error: #{e.message}"
    render json: {
      radius_enabled: false,
      error: e.message,
      timestamp: Time.current.iso8601
    }, status: 500
  end

  private

  # Validate that required RADIUS parameters are present
  def validate_radius_request
    return true if action_name == 'status'

    unless params[:username].present?
      render json: {
        success: false,
        error: 'Username is required'
      }, status: 400
      return false
    end

    if action_name == 'authenticate' && !params[:password].present?
      render json: {
        success: false,
        error: 'Password is required for authentication'
      }, status: 400
      return false
    end

    true
  end

  # Log incoming RADIUS requests
  def log_radius_request
    return if action_name == 'status'

    log_data = {
      action: action_name,
      username: params[:username],
      nas_ip: params[:nas_ip] || request.remote_ip,
      calling_station_id: params[:calling_station_id],
      user_agent: request.user_agent,
      timestamp: Time.current
    }

    Rails.logger.info "RADIUS_API_REQUEST: #{log_data.to_json}"
  end

  # Build RADIUS reply attributes based on authentication result
  def build_reply_attributes(auth_result)
    attributes = {
      'Session-Timeout' => auth_result[:session_timeout] || 86400
    }

    # Add device-specific attributes if available
    if auth_result[:device]
      device = auth_result[:device]
      attributes['Framed-IP-Address'] = device.last_ap if device.last_ap.present?
    end

    # Add client-specific attributes
    if auth_result[:client]
      client = auth_result[:client]
      # Could add bandwidth limits, etc.
      attributes['Session-Timeout'] = [attributes['Session-Timeout'], client.guest_max].min if client.guest_max > 0
    end

    attributes
  end

  # Find user information for authorization without password
  def find_user_info(username, calling_station_id = nil)
    # Try phone number
    normalized_phone = username.gsub(/\D/, '')
    if normalized_phone.present?
      client = Client.joins(:tenant)
                    .where("REGEXP_REPLACE(phone, '[^0-9]', '') = ?", normalized_phone)
                    .where(active: true, tenants: { active: true })
                    .first

      if client
        device = client.devices.where(active: true).first
        return {
          found: true,
          type: 'client',
          client: client,
          device: device,
          tenant: client.tenant,
          session_timeout: device&.time_limit&.minutes || 86400
        }
      end
    end

    # Try email
    if username.include?('@')
      # Try client email
      client = Client.joins(:tenant)
                    .where(email: username, active: true)
                    .where(tenants: { active: true })
                    .first

      if client
        device = client.devices.where(active: true).first
        return {
          found: true,
          type: 'client_email',
          client: client,
          device: device,
          tenant: client.tenant,
          session_timeout: device&.time_limit&.minutes || 86400
        }
      end

      # Try admin user email
      user = User.joins(:tenant)
                .where(email: username, active: true)
                .where(tenants: { active: true })
                .first

      if user
        return {
          found: true,
          type: 'admin_user',
          user: user,
          tenant: user.tenant,
          session_timeout: 86400
        }
      end
    end

    # Try MAC address
    if calling_station_id.present?
      mac = calling_station_id.downcase.gsub(/[^0-9a-f]/, '').scan(/.{2}/).join(':')
      device = Device.joins(client: :tenant)
                     .where(mac_address: mac, active: true)
                     .where(clients: { active: true })
                     .where(tenants: { active: true })
                     .first

      if device
        return {
          found: true,
          type: 'device_mac',
          device: device,
          client: device.client,
          tenant: device.client.tenant,
          session_timeout: device.time_limit&.minutes || 86400
        }
      end
    end

    { found: false }
  end

  # Handle accounting start records
  def handle_accounting_start
    username = params[:username]
    session_id = params[:acct_session_id]
    nas_ip = params[:nas_ip]
    
    # Find associated device and update last_authenticated_at
    user_info = find_user_info(username, params[:calling_station_id])
    
    if user_info[:found] && user_info[:device]
      user_info[:device].update(
        last_authenticated_at: Time.current,
        last_ap: nas_ip
      )
    end

    Rails.logger.info "RADIUS Session Started: #{username} (#{session_id})"
  end

  # Handle accounting stop records  
  def handle_accounting_stop
    username = params[:username]
    session_id = params[:acct_session_id]
    session_time = params[:acct_session_time]
    
    Rails.logger.info "RADIUS Session Ended: #{username} (#{session_id}) - Duration: #{session_time}s"
    
    # Could update device statistics, session history, etc.
  end

  # Handle accounting update records
  def handle_accounting_update
    username = params[:username] 
    session_id = params[:acct_session_id]
    input_octets = params[:acct_input_octets]
    output_octets = params[:acct_output_octets]
    
    Rails.logger.debug "RADIUS Session Update: #{username} (#{session_id}) - In: #{input_octets}, Out: #{output_octets}"
  end

  # Check if database is connected
  def database_connected?
    ActiveRecord::Base.connection.execute('SELECT 1')
    true
  rescue
    false
  end

  # Check if FreeRADIUS tables exist
  def check_freeradius_tables
    tables = %w[radcheck radreply radacct nas radpostauth]
    existing_tables = []
    
    tables.each do |table|
      begin
        ActiveRecord::Base.connection.execute("SELECT 1 FROM #{table} LIMIT 1")
        existing_tables << table
      rescue
        # Table doesn't exist or not accessible
      end
    end
    
    {
      required: tables,
      existing: existing_tables,
      missing: tables - existing_tables
    }
  rescue => e
    { error: e.message }
  end

  # Get counts of active users/devices
  def get_active_user_counts
    {
      active_clients: Client.where(active: true).count,
      active_devices: Device.where(active: true).count,
      active_admin_users: User.where(active: true).count,
      radius_users: begin
        ActiveRecord::Base.connection.execute('SELECT COUNT(*) FROM radcheck').first[0]
      rescue
        'N/A'
      end
    }
  rescue => e
    { error: e.message }
  end
end
