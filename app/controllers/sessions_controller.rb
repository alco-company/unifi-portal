class SessionsController < ApplicationController
  layout "guest"
  # ap=74:83:c2:29:5f:f6
  # id=b6:b8:cb:76:a8:1f
  # t=1750764123
  # url=http://netcts.cdn-apple.com%2F
  # ssid=alco-free"
  # for 188.228.84.87
  # at 2025-06-24 13:22:10 +0200
  def new
    Rails.logger.error("GET: with these parameters #{params.inspect}")
    load_site
    unless @site.nil?
      Rails.logger.error("GET: site found: #{@site.inspect}")
      if device_is_authorized?
        Rails.logger.error("GET: device is authorized, redirecting to success page")
        do_redirect and return
      else
        params[:sid] = @site.id
        params[:tid] = @site.tenant_id
        render :new
      end
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
      Rails.logger.info("Device found or created: #{device.client.inspect}") if device
      if !device.nil? and device.client.active?
        session[:did] = device.id
        session[:url] = user[:url].present? ? user[:url] : "http://captive.apple.com"
        begin

          result = OtpMailer.send_otp(device.client.email, device.last_otp).deliver_later if email_available?(device)
          result2= SmsSender.send_code(device.client.phone, device.last_otp) if sms_available?(device)

          if result || result2
            session[:otp] = device.last_otp if Rails.env.test?
            respond_to do |format|
              format.turbo_stream {
                render turbo_stream: [
                  turbo_stream.replace("otp_input", partial: "sessions/otp_form", locals: { site_id: params[:sid] }),
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
        result = OtpMailer.send_otp(device.client.email, device.last_otp).deliver_later if email_available?(device)
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
    Rails.logger.error("PATCH: with these parameters #{params.inspect}")
    @site = Site.find_by(id: params[:sid]) if params[:site_id].present?
    if otp_valid? && authorize_guest?
      expire_at = @device.client.created_at < 5.minute.ago ? 10.years.from_now : 24.hours.from_now
      Rails.logger.error("PATCH: will expire this device at #{expire_at}")
      Device.find(session[:did]).update!(
        last_authenticated_at: Time.current,
        authentication_expire_at: expire_at,
        active: true
      )
      Rails.logger.error("Device authenticated successfully: #{session[:did]}")
      session.delete(:did)

      do_redirect and return
      # respond_to do |format|
      #   # format.turbo_stream { render turbo_stream: turbo_stream.action(:redirect, params[:url]) }
      #   format.html { redirect_to params[:url], allow_other_host: true, status: :found }
      # end
    else
      respond_to do |format|
        # format.turbo_stream { render turbo_stream: turbo_stream.replace("otp_input", partial: "sessions/failed") }
        format.html { redirect_to new_session_path(site_name: @site.name,
          phone: @device&.client&.phone,
          ap: params[:ap],
          ssid: params[:ssid],
          tid: params[:tid],
          sid: params[:sid],
          id: params[:id],
          url: params[:url],
          t: params[:t]), alert: @error }
      end
    end
  end

  private

    def load_site
      @client = nil
      @site = Site.where(ssid: params["ssid"], url: request.remote_addr, active: true).first# , ssid: params["ssid"], name: params["site_name"], ).first
    rescue
      Rails.logger.error("Failed to load site with name: #{params['site_name']} and URL: #{request.remote_addr}")
      @site = nil
    end

    def do_redirect
      respond_to do |format|
        format.html {
          case params[:url]
          when /apple/; render "success", layout: "success", status: 200
          when /generate_204/; head :no_content
          when /googleapis\.com/; head :no_content
          when /msftconnect/; render plain: "Microsoft Connect Test", status: 200
          when /msftncsi/; render plain: "Microsoft NCSI"
          when /gnome/; render plain: "NetworkManager is online"
          when /check\.kde\.org/; render plain: "OK"
          else
              render plain: params[:url] || "No URL provided"
          end
        }
      end
    end

    def find_or_create_user_client(user)
      @client = Client.where(tenant_id: user[:tid], phone: user[:phone]).first_or_initialize
      @client.update!(name: user[:name], active: true) if @client.name != user[:name] && user[:name].present? && user[:name] != ""
      @client.update!(email: user[:email]) if @client.email != user[:email] && user[:email].present? && user[:email] != ""
      expire_at = @client.created_at < 5.minute.ago ? 10.years.from_now : 24.hours.from_now
      device = Device.find_or_create_by!(client_id: @client.id, mac_address: user[:id])
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
      Rails.logger.error("PATCH: testing the OTP validity: #{params[:otp]} ")

      if params[:did] && session[:did] && params[:did] == session[:did].to_s
        Rails.logger.error("PATCH: did matches session did, more")
        @device = Device.find_by(id: session[:did])
        Rails.logger.error("PATCH: device found: #{@device.inspect}")
        if @device.nil? || @device.last_otp.nil? || !@device.client.active?
          errs = []
          errs << "Device not found" if @device.nil?
          errs << "User not active" if !@device&.client&.active?
          errs << "OTP wrong" if @device&.last_otp&.nil?
          @error = errs.join(", ")
          return false
        end
        @error = "Invalid OTP code"
        @device.last_otp == params[:otp]
      else
        @error = "Invalid device ID or session expired"
        false
      end
    end

    def authorize_guest?
      return false if @device.nil?
      result = @device.authorize
      if result[:success]
        Rails.logger.info("Guest access authorized for device: #{@device.id}")
        true
      else
        @error = result[:error]
        false
      end
    end

    def device_is_authorized?
      Device.authorized?(params[:id])
    end
end
