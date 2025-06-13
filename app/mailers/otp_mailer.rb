class OtpMailer < ApplicationMailer
  default from: "info@mortimer.pro" # Customize your sender email

  def send_otp(user_email, otp_code)
    @otp_code = otp_code
    mail(to: user_email, subject: "Your One-Time Password (OTP)")
  end
end