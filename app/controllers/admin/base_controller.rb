class Admin::BaseController < ApplicationController
  # layout "admin/application"
  helper_method :current_user

  # Ensure the user is logged in as an admin
  before_action :require_user!

  # Ensure the user has admin privileges
  before_action :restrict_to_tenant!

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def require_user!
    redirect_to admin_login_path unless current_user
  end

  def restrict_to_tenant!
    unless current_user.superuser?
      @tenant = current_user.tenant
    end
  end
end
