class SessionsController < ApplicationController

  # ap=74:83:c2:29:5f:f6
  # id=b6:b8:cb:76:a8:1f
  # t=1750764123
  # url=http://netcts.cdn-apple.com%2F
  # ssid=alco-free" 
  # for 188.228.84.87 
  # at 2025-06-24 13:22:10 +0200
  def new
    load_site
    unless @site.nil?
      params[:sid] = @site.id
      params[:tid] = @site.tenant_id
      render :new
    else
      render :error, status: :not_found
    end
  end

  # tid = tenant_id
  # sid = site_id
  # did = device_id
  def create
    user = params.permit(:tid, :sid, :ap, :id, :url, :ssid, :t, :name, :email, :phone)

    if valid_user_input?(user)
      device = find_or_create_user_client(user)
      debugger
      unless device.nil?
        session[:did] = device.id
        begin
        
          result = OtpMailer.send_otp( device.client.email, device.last_otp).deliver_later if email_available?(device)
          result2= SmsSender.send_code(device.client.phone, device.last_otp) if sms_available?(device)
  
          if result || result2
            session[:otp] = device.last_otp if Rails.env.test?
            respond_to do |format|
              format.turbo_stream { 
                render turbo_stream: [
                  turbo_stream.replace("otp_input", partial: "sessions/otp_form"), 
                  turbo_stream.append("flash_toasts", partial: "shared/toast", locals: {
                    message: "Code sent successfully",
                    type: :success
                  })
                ]
              }
              format.html { redirect_to otp_path } # fallback
            end
          else
            some_fault(status: :unprocessable_entity)
          end
            
        rescue => e
          some_fault(status: :unprocessable_entity)
        end
      else
        some_fault(status: :unprocessable_entity)
      end
    else
      some_fault(status: :unprocessable_entity)
    end
  end

  def some_fault(status:)
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace("login_form", partial: "sessions/new") }
      format.html { render :new, status: status }
    end
  rescue => e
    logger.error("Error in some_fault: #{e.message}")
  end

  def otp
    @device = Device.find_by(id: session[:did])
  end

  def resend
    device = Device.find_by(id: session[:did])
    unless device.nil?
      session[:did] = device.id
      device.update!(last_otp: OtpGenerator.generate_otp) if @device.present?
    
      begin
        result = OtpMailer.send_otp( device.client.email, device.last_otp).deliver_later if email_available?(device)
        result2= SmsSender.send_code(device.client.phone, device.last_otp) if sms_available?(device)
        if result || result2
          session[:otp] = device.last_otp if Rails.env.test?
          respond_to do |format|
            format.turbo_stream {
              render turbo_stream: [
                turbo_stream.replace("otp_input", partial: "sessions/otp_form"),
                turbo_stream.append("flash_toasts", partial: "shared/toast", locals: {
                  message: "Code sent successfully",
                  type: :success
                })
              ]    
            }
            format.html { render partial: "sessions/otp_form" }
          end
        end
  
      rescue => e
        logger.error("OTP resend failed: #{e.message}")
        render turbo_stream: turbo_stream.append("flash_toasts", partial: "shared/toast", locals: {
          message: "Failed to resend code. Please try again.",
          type: :error
        }), status: :internal_server_error
      end
    end
  end

  def update
    if otp_valid? && authorize_guest!
      session.delete(:did)

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
      @client = nil
      @site = Site.where(url: params[:url]).or(Site.where(ssid: params[:ssid])).first
    rescue
      @site = nil
    end

    def find_or_create_user_client(user)
      client = Client.find_or_create_by!(tenant_id: user[:tid], email: user[:email], phone: user[:phone])
      client.update!(name: user[:name], active: true) if client.name != user[:name]
      expire_at = client.created_at < 1.minute.ago ? 24.hours.from_now : 10.years.from_now
      device = Device.find_or_create_by!(client_id: client.id, mac_address: user[:id])
      device.update!(
        last_ap: user[:ap],
        site_id: user[:sid],
        last_authenticated_at: Time.current,
        authentication_expire_at: expire_at,
        last_otp: OtpGenerator.generate_otp
      )
      device
    rescue
      nil
    end

    def email_available?(device)
      device.client.email.present? && device.client.email =~ URI::MailTo::EMAIL_REGEXP
    rescue
      false
    end

    def sms_available?(device)
      device.client.phone.present? && device.client.phone =~ /^(\+?[1-9]\d){0,1}\d{8}$/
    rescue
      false
    end

    def valid_user_input?(data)
      data[:phone].present? || data[:name].present? && data[:email] =~ URI::MailTo::EMAIL_REGEXP # && data[:phone].present?
    end

    def otp_valid?
      if params[:did] && session[:did] && params[:did] == session[:did].to_s
        @device = Device.find_by(id: session[:did])
        return false if @device.nil? || @device.last_otp.nil?
        @device.last_otp == params[:otp]
      else
        return false
      end
    end

    def authorize_guest!
      return false unless @device && @device.site #&& @client
      load_client_info
      result = External::Unifi.authorize_guest(
        url: @device.site.controller_url,
        site_id: @device.site.unifi_id,
        client_id: @device.unifi_id,
        api_key: @device.site.api_key
      )
      !result.nil? && result.dig("action").present? && result["action"] == "AUTHORIZE_GUEST_ACCESS" ?
        { success: true } :
        { success: false, error: result["error"] || "Failed to authorize guest access" }
    end

    def load_client_info
      site_info = External::Unifi.get_sites(@device.site&.controller_url, key: @device.site&.api_key)
      @device.site.unifi_id = site_info["data"].first["id"]
      @unifi_client = External::Unifi.get_client(@device.site.controller_url, @device.site.unifi_id, @device.mac_address, key: @device.site&.api_key)
      unless @unifi_client.nil? ||
        @unifi_client.dig("count").zero? ||
        @unifi_client.dig("data").nil? ||
        @unifi_client.dig("data").empty? ||
        @unifi_client.dig("count") > 1
        @device.unifi_id = @unifi_client["data"].first["id"]
      end
    end

end