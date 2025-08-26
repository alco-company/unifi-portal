class Admin::NasController < Admin::BaseController
  before_action :current_tenant
  before_action :set_site
  before_action :set_nas, only: %i[show edit update destroy]

  # GET /admin/nas or /admin/nas.json
  def index
    @nas = @site.nas
    @nas = case_insensitive_match(@nas, [ :nasname, :shortname, :nas_type, :ports, :community, :description ])
  end

  # GET /admin/nas/1 or /admin/nas/1.json
  def show
  end

  # GET /admin/nas/new
  def new
    @nas = @site.nas.build
  end

  # GET /admin/nas/1/edit
  def edit
  end

  # POST /admin/nas or /admin/nas.json
  def create
    @nas = @site.nas.build(nas_params)
    # Generate secret if not provided
    @nas.secret = SecureRandom.hex(16) if @nas.secret.blank?
    
    respond_to do |format|
      if @nas.save
        # Update FreeRADIUS configuration
        update_freeradius_config
        
        format.html { redirect_to admin_tenant_site_nas_path(@tenant, @site, @nas), notice: "Nas was successfully created." }
        format.json { render :show, status: :created, location: admin_tenant_site_nas_path(@tenant, @site, @nas) }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @nas.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/nas/1 or /admin/nas/1.json
  def update
    respond_to do |format|
      if @nas.update(nas_params)
        # Update FreeRADIUS configuration
        update_freeradius_config
        
        format.html { redirect_to admin_tenant_site_nas_path(@tenant, @site, @nas), notice: "Nas was successfully updated." }
        format.json { render :show, status: :ok, location: admin_tenant_site_nas_path(@tenant, @site, @nas) }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @nas.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /admin/nas/1 or /admin/nas/1.json
  def destroy
    @nas.destroy!
    
    # Update FreeRADIUS configuration
    update_freeradius_config
    
    respond_to do |format|
      format.html { redirect_to admin_tenant_site_nas_index_path(@tenant, @site), status: :see_other, notice: "Nas was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def delete_all
    @nas = current_user.superuser? ? Nas.all : Nas.where(site_id: params[:site_id])
    case_insensitive_match(@nas, [ :nasname, :shortname, :nas_type, :ports, :community, :description ]).destroy_all
    
    # Update FreeRADIUS configuration
    update_freeradius_config

    respond_to do |format|
      format.html { redirect_to admin_tenant_site_nas_index_path(@tenant, @site), status: :see_other, notice: "All nas were successfully deleted." }
      format.json { head :no_content }
    end
  end

  private

    def set_site
      @site = @tenant.sites.find(params[:site_id])
    end

    # Use callbacks to share common setup or constraints between actions.
    def set_nas
      @nas = @site.nas.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def nas_params
      params.require(:nas).permit(:nasname, :shortname, :nas_type, :ports, :secret, :server, :community, :description)
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
        config_lines << "    require_message_authenticator = yes"
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
end
