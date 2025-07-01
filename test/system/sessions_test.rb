# test/system/session_test.rb
require "application_system_test_case"

class SessionsTest < ApplicationSystemTestCase
  setup do
    @tenant = tenants(:one)
    @site = sites(:one)
    @client = clients(:one)
    @device = devices(:one)
    @site.unifi_id = "88f7af54-98f8-306a-a1c7-c9349722b1f6" # Mocking the site ID for Unifi API
    stub_unifi_sites_api(@site.unifi_id)
    stub_unifi_client_api(@device.mac_address)
    stub_guest_authorization_api
    stub_mailersend_api
    stub_smsapi(@client.phone.gsub("+", ""), "123456") # Stub the SMS API to return a fixed OTP code - leave out the '+' 
  end

  test "user completes OTP login flow using only valid pnr" do

    visit new_session_path(
      url:  @site.url,
      ssid: @site.ssid,
      id:   @device.mac_address,
      ap:   @device.last_ap,
      t:    Time.current.to_i
    )

    OtpGenerator.stub(:generate_otp, "123456") do
      within("form") do
        fill_in "Dit telefonnummer", with: @client.phone
        find("input[name='phone']").send_keys(:tab)
        fill_in "For- og efternavn", with: "Alice"
        fill_in "Din email adresse", with: "alice@example.com"
        # assert_selector "input[name='email'][disabled]", wait: 3
        click_button "Send mig en OTP"
      end
  
      # adding the OTP code programmatically for testing purposes
      # fill_in "OTP adgangskode", with: "123456"
      click_button "Godkend"
  
      assert_text "nu tilsluttet"
    end
  end

  test "user completes OTP login flow (with Turbo)" do

    visit new_session_path(
      url:  "https://heimdall.test",
      ssid: "thisted-guest",
      id:   @device.mac_address,  # "1c:71:25:63:e4:24",
      ap:   @device.last_ap,      # "94:2a:6f:d0:30:57",
      t:    Time.current.to_i
    )

    OtpGenerator.stub(:generate_otp, "123456") do
      within("form") do
        fill_in "Dit telefonnummer", with: @client.phone
        find("input[name='phone']").send_keys(:tab)
        fill_in "For- og efternavn", with: "Alice"
        fill_in "Din email adresse", with: "alice@example.com"
        click_button "Send mig en OTP"
      end
  
      # adding the OTP code programmatically for testing purposes
      # fill_in "OTP adgangskode", with: "123456"
      click_button "Godkend"
  
      assert_text "nu tilsluttet"
    end
  end


  test "user completes OTP login flow (with/out Turbo)" do

    visit new_session_path(
      url:  "https://heimdall.test",
      ssid: "thisted-guest",
      id:   @device.mac_address,
      ap:   @device.last_ap,
      t:    Time.current.to_i
    )

    OtpGenerator.stub(:generate_otp, "123456") do
      within("form") do
        fill_in "Dit telefonnummer", with: @client.phone
        find("input[name='phone']").send_keys(:tab)
        fill_in "For- og efternavn", with: "Alice"
        fill_in "Din email adresse", with: "alice@example.com"
        click_button "Send mig en OTP"
      end
  
      # adding the OTP code programmatically for testing purposes
      # fill_in "OTP adgangskode", with: "123456"
      # save_screenshot(Rails.root.join("tmp", "otp_fallback.png"))
      click_button "Godkend"
    
      assert_text "nu tilsluttet"
    end
  end  
end