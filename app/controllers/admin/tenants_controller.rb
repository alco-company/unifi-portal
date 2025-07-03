class Admin::TenantsController < Admin::BaseController
  before_action :current_tenant

  # GET /admin/tenants or /admin/tenants.json
  def index
    if current_user.superuser?
      @tenants = Tenant.all
    else
      @tenants = Tenant.where(id: current_user.tenant_id)
    end
    @tenants = case_insensitive_match(@tenants, [ :name, :url, :note ], params[:query]) if params[:query].present?
  end

  # GET /admin/tenants/1 or /admin/tenants/1.json
  def show
  end

  # GET /admin/tenants/new
  def new
    @tenant = Tenant.new
  end

  # GET /admin/tenants/1/edit
  def edit
  end

  # POST /admin/tenants or /admin/tenants.json
  def create
    @tenant = Tenant.new(tenant_params)

    respond_to do |format|
      if @tenant.save
        format.html { redirect_to admin_tenants_path, notice: "Tenant was successfully created." }
        format.json { render :show, status: :created, location: admin_tenants_path }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @tenant.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/tenants/1 or /admin/tenants/1.json
  def update
    respond_to do |format|
      if @tenant.update(tenant_params)
        format.html { redirect_to admin_tenants_path, notice: "Tenant was successfully updated." }
        format.json { render :show, status: :ok, location: admin_tenants_path }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @tenant.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /admin/tenants/1 or /admin/tenants/1.json
  def destroy
    if @tenant.present?
      @tenant.destroy!

      respond_to do |format|
        format.html { redirect_to admin_tenants_path, status: :see_other, notice: "Tenant was successfully destroyed." }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_to admin_tenants_path, status: :see_other, alert: "Tenant not found." }
        format.json { render json: { error: "Tenant not found." }, status: :not_found }
      end
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_tenant
      @tenant = current_tenant
    end

    # Only allow a list of trusted parameters through.
    def tenant_params
      params.expect(tenant: [ :name, :url, :guest_max, :guest_rx, :guest_tx, :active, :note ])
    end
end
