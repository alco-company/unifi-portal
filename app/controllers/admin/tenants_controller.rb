class Admin::TenantsController < ApplicationController
  before_action :set_admin_tenant, only: %i[ show edit update destroy ]

  # GET /admin/tenants or /admin/tenants.json
  def index
    @admin_tenants = Admin::Tenant.all
  end

  # GET /admin/tenants/1 or /admin/tenants/1.json
  def show
  end

  # GET /admin/tenants/new
  def new
    @admin_tenant = Admin::Tenant.new
  end

  # GET /admin/tenants/1/edit
  def edit
  end

  # POST /admin/tenants or /admin/tenants.json
  def create
    @admin_tenant = Admin::Tenant.new(admin_tenant_params)

    respond_to do |format|
      if @admin_tenant.save
        format.html { redirect_to @admin_tenant, notice: "Tenant was successfully created." }
        format.json { render :show, status: :created, location: @admin_tenant }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @admin_tenant.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/tenants/1 or /admin/tenants/1.json
  def update
    respond_to do |format|
      if @admin_tenant.update(admin_tenant_params)
        format.html { redirect_to @admin_tenant, notice: "Tenant was successfully updated." }
        format.json { render :show, status: :ok, location: @admin_tenant }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @admin_tenant.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /admin/tenants/1 or /admin/tenants/1.json
  def destroy
    @admin_tenant.destroy!

    respond_to do |format|
      format.html { redirect_to admin_tenants_path, status: :see_other, notice: "Tenant was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_admin_tenant
      @admin_tenant = Admin::Tenant.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def admin_tenant_params
      params.expect(admin_tenant: [ :name, :url, :login, :password, :guest_max, :guest_rx, :guest_tx, :active ])
    end
end
