# test/system/session_test.rb
require "application_system_test_case"

class SessionsTest < ApplicationSystemTestCase
  setup do
    stub_unifi_sites_api
    stub_unifi_client_api("1c:71:25:63:e4:24")
    stub_guest_authorization_api
  end

  test "user completes OTP login flow" do

    visit new_session_path(
      url:  "https://localhost:3000",
      ssid: "thisted-guest",
      id:   "1c:71:25:63:e4:24",
      ap:   "94:2a:6f:d0:30:57",
      t:    Time.current.to_i
    )

    within("turbo-frame#login_form") do
      fill_in "For- og efternavn", with: "Alice"
      fill_in "Dit P-nr", with: "123456-7890"
      fill_in "Din email adresse", with: "alice@example.com"
      fill_in "Dit telefonnummer", with: "+4511122233"
      click_button "Send mig en OTP"
    end
    
    fill_in "OTP adgangskode", with: "123456"
    click_button "Godkend"
  
    assert_text "now connected"
  end
end