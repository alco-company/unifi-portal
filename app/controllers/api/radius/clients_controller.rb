# app/controllers/api/radius/clients_controller.rb

class Api::Radius::ClientsController < ApplicationController
  # Skip CSRF protection for API calls
  skip_before_action :verify_authenticity_token
  
  before_action :authenticate_api_user!
  before_action :find_nas_client, only: [:show, :update, :destroy, :test_connection]

  # GET /api/radius/clients
  # List all RADIUS clients (NAS devices)
  def index
    clients = Nas.includes(:site).all
    
    render json: {
      success: true,
      clients: clients.map { |client| format_client_response(client) },
      count: clients.count
    }, status: 200
  end

  # POST /api/radius/clients
  # Create a new RADIUS client
  def create
    client_params = radius_client_params
    client_params[:secret] = generate_secret if client_params[:secret].blank?
    
    client = Nas.new(client_params)
    
    if client.save
      # Generate updated FreeRADIUS config
      update_freeradius_config
      
      render json: {
        success: true,
        client: format_client_response(client),
        message: "RADIUS client created successfully"
      }, status: 201
    else
      render json: {
        success: false,
        errors: client.errors.full_messages
      }, status: 422
    end
  end

  # GET /api/radius/clients/:id
  # Show specific RADIUS client
  def show
    render json: {
      success: true,
      client: format_client_response(@client)
    }, status: 200
  end

  # PUT/PATCH /api/radius/clients/:id
  # Update RADIUS client
  def update
    if @client.update(radius_client_params)
      # Generate updated FreeRADIUS config
      update_freeradius_config
      
      render json: {
        success: true,
        client: format_client_response(@client),
        message: "RADIUS client updated successfully"
      }, status: 200
    else
      render json: {
        success: false,
        errors: @client.errors.full_messages
      }, status: 422
    end
  end

  # DELETE /api/radius/clients/:id
  # Delete RADIUS client
  def destroy
    @client.destroy
    
    # Generate updated FreeRADIUS config
    update_freeradius_config
    
    render json: {
      success: true,
      message: "RADIUS client deleted successfully"
    }, status: 200
  end

  # POST /api/radius/clients/:id/test_connection
  # Test connection to a RADIUS client
  def test_connection
    test_result = test_nas_connection(@client)
    
    render json: {
      success: true,
      client: format_client_response(@client),
      test_result: test_result
    }, status: 200
  end

  # POST /api/radius/clients/generate_config
  # Generate FreeRADIUS clients.conf content
  def generate_config
    config_content = generate_freeradius_config
    
    render json: {
      success: true,
      config: config_content,
      clients_count: Nas.count,
      generated_at: Time.current.iso8601
    }, status: 200
  end

  # POST /api/radius/clients/reload_freeradius
  # Trigger FreeRADIUS configuration reload
  def reload_freeradius
    success = reload_freeradius_service
    
    if success
      render json: {
        success: true,
        message: "FreeRADIUS configuration reloaded successfully"
      }, status: 200
    else
      render json: {
        success: false,
        message: "Failed to reload FreeRADIUS configuration"
      }, status: 500
    end
  end

  private

  # Authenticate API requests - you can customize this based on your auth system
  def authenticate_api_user!
    # Skip authentication in development
    return true if Rails.env.development?
    
    # For now, we'll use a simple API key or skip authentication
    # In production, implement proper API authentication
    api_key = request.headers['X-API-Key'] || params[:api_key]
    
    # Simple API key check - customize this for your needs
    unless api_key == Rails.application.credentials.radius_api_key
      render json: { 
        success: false, 
        error: 'Unauthorized - Valid API key required' 
      }, status: 401
      return false
    end
    
    true
  end

  def find_nas_client
    @client = Nas.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      error: 'RADIUS client not found'
    }, status: 404
  end

  def radius_client_params
    params.require(:client).permit(
      :nasname, :shortname, :secret, :nas_type, :description, 
      :site_id, :ports, :server, :community
    )
  end

  def format_client_response(client)
    {
      id: client.id,
      nasname: client.nasname,
      shortname: client.shortname,
      nas_type: client.nas_type,
      description: client.description,
      site: client.site&.name,
      ports: client.ports,
      server: client.server,
      community: client.community,
      created_at: client.created_at.iso8601,
      updated_at: client.updated_at.iso8601,
      # Don't expose the secret in responses for security
      has_secret: client.secret.present?
    }
  end

  def generate_secret
    SecureRandom.hex(16)
  end

  def generate_freeradius_config
    config_lines = []
    
    # Add localhost client
    config_lines << "client localhost {"
    config_lines << "    ipaddr = 127.0.0.1"
    config_lines << "    secret = testing123"
    config_lines << "    require_message_authenticator = no"
    config_lines << "}"
    config_lines << ""
    
    # Add Docker network client
    config_lines << "client docker {"
    config_lines << "    ipaddr = 172.16.0.0/12"
    config_lines << "    secret = testing123"
    config_lines << "    require_message_authenticator = no"
    config_lines << "}"
    config_lines << ""

    # Add each NAS client from database
    Nas.all.find_each do |client|
      config_lines << "client #{client.shortname} {"
      config_lines << "    ipaddr = #{client.nasname}"
      config_lines << "    secret = #{client.secret}"
      config_lines << "    require_message_authenticator = no"
      config_lines << "    shortname = #{client.shortname}"
      
      if client.nas_type.present?
        config_lines << "    type = #{client.nas_type}"
      end
      
      if client.description.present?
        config_lines << "    # #{client.description}"
      end
      
      config_lines << "}"
      config_lines << ""
    end

    config_lines.join("\n")
  end

  def update_freeradius_config
    return unless Rails.env.production? || ENV['FREERADIUS_AUTO_UPDATE'] == 'true'
    
    begin
      config_content = generate_freeradius_config
      
      # Write to FreeRADIUS container via docker exec
      container_name = ENV['FREERADIUS_CONTAINER_NAME'] || 'heimdall-freeradius'
      temp_file = "/tmp/clients_#{SecureRandom.hex(4)}.conf"
      
      # Write config to temporary file
      File.write(temp_file, config_content)
      
      # Copy to container
      system("docker cp #{temp_file} #{container_name}:/etc/raddb/clients.conf")
      
      # Signal FreeRADIUS to reload config (HUP signal)
      system("docker exec #{container_name} kill -HUP $(pidof radiusd)")
      
      # Clean up temp file
      File.delete(temp_file) if File.exist?(temp_file)
      
      Rails.logger.info "FreeRADIUS configuration updated with #{Nas.count} clients"
      
      true
    rescue => e
      Rails.logger.error "Failed to update FreeRADIUS config: #{e.message}"
      false
    end
  end

  def reload_freeradius_service
    return true unless Rails.env.production? || ENV['FREERADIUS_AUTO_UPDATE'] == 'true'
    
    begin
      container_name = ENV['FREERADIUS_CONTAINER_NAME'] || 'heimdall-freeradius'
      
      # Send HUP signal to reload configuration
      system("docker exec #{container_name} kill -HUP $(pidof radiusd)")
      
      Rails.logger.info "FreeRADIUS configuration reload triggered"
      true
    rescue => e
      Rails.logger.error "Failed to reload FreeRADIUS: #{e.message}"
      false
    end
  end

  def test_nas_connection(client)
    # Basic connectivity test
    begin
      require 'socket'
      require 'timeout'
      
      Timeout::timeout(3) do
        TCPSocket.new(client.nasname, 80).close
        { status: 'reachable', message: 'Host is reachable' }
      end
    rescue => e
      { status: 'unreachable', message: e.message }
    end
  end
end
