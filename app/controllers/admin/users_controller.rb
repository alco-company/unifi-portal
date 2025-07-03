class Admin::UsersController < Admin::BaseController
  before_action :current_tenant
  before_action :set_user, only: %i[show edit update destroy]

  # GET /users or /users.json
  def index
    @users = @tenant.users.all
    @users = case_insensitive_match(@users, [ :name, :email, :phone ])
  end

  # GET /users/1 or /users/1.json
  def show
  end

  # GET /users/new
  def new
    @user = @tenant.users.new
  end

  # GET /users/1/edit
  def edit
    if @user.superuser? && !current_user.superuser?
      redirect_to admin_tenant_users_path(@tenant), alert: "You cannot edit a superuser."
      nil
    end
  end

  # POST /users or /users.json
  def create
    @user = @tenant.users.new(user_params)

    if @user.save
      redirect_to admin_tenant_users_path(@tenant), notice: "User was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /users/1 or /users/1.json
  def update
    if @user.update(user_params)
      redirect_to admin_tenant_users_path(@tenant), notice: "User was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /users/1 or /users/1.json
  def destroy
    @user.destroy!
    redirect_to admin_tenant_users_path(@tenant), status: :see_other, notice: "User was successfully destroyed."
  end

  def delete_all
    @users = @tenant.users # current_user.superuser? ? Device.all : Device.where(tenant_id: current_user.tenant_id)
    case_insensitive_match(@users, [ :name, :email, :phone ]).destroy_all

    respond_to do |format|
      format.html { redirect_to admin_tenant_users_path(@tenant), status: :see_other, notice: "All users were successfully deleted." }
      format.json { head :no_content }
    end
  end

  private

  def set_user
    @user = @tenant.users.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :password, :active)
  end
end
