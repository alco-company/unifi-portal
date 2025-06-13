class OtpMailerPreview < ActionMailer::Preview
  def send_otp
    OtpMailer.send_otp("user@example.com", "123456")
  end
end