require "test_helper"

class OtpMailerTest < ActionMailer::TestCase
  test "send_otp delivers the OTP to the user" do
    user_email = "user@example.com"
    otp_code = "123456"
    stub_mailersend_api()

    email = OtpMailer.send_otp(user_email, otp_code)

    # Verify email was queued for delivery
    assert_emails 1 do
      email.deliver_now
    end

    # Check the basic headers
    assert_equal [ "info@unifi-portal.site" ], email.from
    assert_equal [ user_email ], email.to
    assert_equal "Din OTP-kode til adgang til netværket", email.subject

    # Check the body content
    assert_includes email.html_part.body.to_s, otp_code
    assert_includes email.text_part.body.to_s, otp_code
  end
end
