class Admin::SessionsController < ApplicationController
  # layout "admin/login" # optional custom login layout

  def new
  end

  def create
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password]) && user.active?
      session[:user_id] = user.id
      redirect_to admin_tenants_path, notice: "Logged in successfully"
    else
      flash.now[:alert] = "Invalid email or password - or user not active"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to admin_login_path, notice: "Logged out"
  end
end
