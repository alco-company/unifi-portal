require "test_helper"

class SmsTest < ActiveSupport::TestCase

  test "sends OTP via SMS" do
    stub_smsapi
  
    SmsSender.send_code("+4553652455", "123456")
  
    assert_requested :post, "https://api.smsapi.com/sms.do", times: 1
  end
end