class Admin::RadiusDevicesController < Admin::BaseController
  before_action :current_tenant
  before_action :set_device, only: [:show, :enable_radius, :disable_radius, :regenerate_otp, :reset_failures]

  # GET /admin/tenants/:tenant_id/radius_devices
  def index
    @devices = @tenant.clients
                      .joins(:devices)
                      .where(active: true)
                      .includes(devices: :site)
                      .flat_map(&:devices)
                      .select { |d| d.site&.radius? }
    
    @devices = @devices.select { |d| device_matches_search?(d) } if params[:search].present?
  end

  # GET /admin/tenants/:tenant_id/radius_devices/:id
  def show
    @client = @device.client
    @site = @device.site
  end

  # POST /admin/tenants/:tenant_id/radius_devices/:id/enable_radius
  def enable_radius
    if @device.site&.radius?
      device_name = params[:device_name].present? ? params[:device_name] : "#{@device.client.name}'s device"
      @device.update!(device_name: device_name)
      
      if @device.enable_radius_access!
        redirect_to admin_tenant_radius_device_path(@tenant, @device), 
                    notice: "RADIUS access enabled. OTP sent via email/SMS."
      else
        redirect_to admin_tenant_radius_device_path(@tenant, @device), 
                    alert: "Failed to enable RADIUS access."
      end
    else
      redirect_to admin_tenant_radius_device_path(@tenant, @device), 
                  alert: "Device site is not configured for RADIUS."
    end
  end

  # DELETE /admin/tenants/:tenant_id/radius_devices/:id/disable_radius
  def disable_radius
    @device.disable_radius_access!
    redirect_to admin_tenant_radius_device_path(@tenant, @device), 
                notice: "RADIUS access disabled."
  end

  # POST /admin/tenants/:tenant_id/radius_devices/:id/regenerate_otp
  def regenerate_otp
    if @device.radius_enabled?
      @device.generate_new_otp!
      redirect_to admin_tenant_radius_device_path(@tenant, @device), 
                  notice: "New OTP generated and sent."
    else
      redirect_to admin_tenant_radius_device_path(@tenant, @device), 
                  alert: "RADIUS is not enabled for this device."
    end
  end

  # POST /admin/tenants/:tenant_id/radius_devices/:id/reset_failures
  def reset_failures
    @device.update!(
      radius_auth_failures: 0,
      radius_locked_until: nil
    )
    redirect_to admin_tenant_radius_device_path(@tenant, @device), 
                notice: "Authentication failures reset."
  end

  # POST /admin/tenants/:tenant_id/radius_devices/bulk_enable
  def bulk_enable
    device_ids = params[:device_ids] || []
    enabled_count = 0
    
    device_ids.each do |device_id|
      device = @tenant.clients.joins(:devices).find_by(devices: { id: device_id })&.devices&.find(device_id)
      if device&.site&.radius?
        device.update!(device_name: "#{device.client.name}'s device") if device.device_name.blank?
        if device.enable_radius_access!
          enabled_count += 1
        end
      end
    end
    
    redirect_to admin_tenant_radius_devices_path(@tenant), 
                notice: "RADIUS enabled for #{enabled_count} devices."
  end

  # POST /admin/tenants/:tenant_id/radius_devices/bulk_disable
  def bulk_disable
    device_ids = params[:device_ids] || []
    disabled_count = 0
    
    device_ids.each do |device_id|
      device = @tenant.clients.joins(:devices).find_by(devices: { id: device_id })&.devices&.find(device_id)
      if device&.radius_enabled?
        device.disable_radius_access!
        disabled_count += 1
      end
    end
    
    redirect_to admin_tenant_radius_devices_path(@tenant), 
                notice: "RADIUS disabled for #{disabled_count} devices."
  end

  private

  def set_device
    @device = @tenant.clients
                    .joins(:devices)
                    .find_by(devices: { id: params[:id] })
                    &.devices
                    &.find(params[:id])
    
    unless @device
      redirect_to admin_tenant_radius_devices_path(@tenant), 
                  alert: "Device not found."
    end
  end

  def device_matches_search?(device)
    search_term = params[:search].downcase
    [
      device.client.name,
      device.client.email,
      device.client.phone,
      device.radius_username,
      device.device_name,
      device.mac_address
    ].compact.any? { |field| field.to_s.downcase.include?(search_term) }
  end
end
