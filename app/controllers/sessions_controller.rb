class SessionsController < ApplicationController
  before_action :load_site, only: [:new, :create, :update]
  before_action :load_client_info, only: [:new]

  def new
    if @client
      render :new
    else
      render :error, status: :not_found
    end
  end

  def create
    @user = params.permit(:ap, :id, :url, :ssid, :t, :name, :pnr, :email, :phone)
    session[:user_data] = @user.to_h

    if valid_user_input?(@user)
      otp = generate_otp
      session[:otp] = otp
      session[:otp_sent_at] = Time.current

      OtpMailer.send_otp(@user[:email], otp).deliver_later
      # SmsSender.send_code(@user[:phone], otp)

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("otp_input", partial: "sessions/otp_form") }
        format.html { redirect_to otp_path } # fallback
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def resend
    user = session[:user_data]
    otp = generate_otp
    session[:otp] = otp
    session[:otp_sent_at] = Time.current
  
    begin
      OtpMailer.send_otp(user["email"], otp).deliver_later
      # SmsSender.send_code(user["phone"], otp)
  
      render turbo_stream: [
        turbo_stream.replace("otp_input", partial: "sessions/otp_form"),
        turbo_stream.append("flash_toasts", partial: "shared/toast", locals: {
          message: "Code sent successfully",
          type: :success
        })
      ]
    rescue => e
      logger.error("OTP resend failed: #{e.message}")
      render turbo_stream: turbo_stream.append("flash_toasts", partial: "shared/toast", locals: {
        message: "Failed to resend code. Please try again.",
        type: :error
      }), status: :internal_server_error
    end
  end

  def update
    if params[:otp] == session[:otp] && otp_valid?
      authorize_guest!
      session.delete(:otp)

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("otp_input", partial: "sessions/success") }
        format.html { redirect_to success_path }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("otp_input", partial: "sessions/failed") }
        format.html { redirect_to otp_path, alert: "Invalid code" }
      end
    end
  end

  private

  def load_site
    @site = Site.where(url: params[:url]).or(Site.where(ssid: params[:ssid])).first
  end

  def load_client_info
    site_info = External::Unifi.get_sites(@site&.controller_url, key: @site&.api_key)
    @site_id = site_info["data"].first["id"]
    @client = External::Unifi.get_client(@site.controller_url, @site_id, params[:id], key: @site&.api_key)
  end

  def valid_user_input?(data)
    data[:name].present? && data[:email] =~ URI::MailTo::EMAIL_REGEXP && data[:phone].present?
  end

  def generate_otp
    rand(100_000..999_999).to_s
  end

  def otp_valid?
    session[:otp_sent_at] && session[:otp_sent_at] > 10.minutes.ago
  end

  def authorize_guest!
    # External::Unifi.authorize_guest(
    #   url: @site.url,
    #   site_id: @site_id,
    #   client_id: session[:client_id],
    #   api_key: @site.api_key
    # )
  end
end