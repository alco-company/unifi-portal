# test/controllers/session_controller_test.rb
require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @site = Site.create!(controller_url: "https://heimdall.test", url: "https://heimdall.test", ssid: "thisted-guest", api_key: "test-key")
    @client_mac = "1c:71:25:63:e4:24"
    stub_unifi_client_api(@client_mac)
    stub_unifi_sites_api()
    stub_guest_authorization_api()
    stub_mailersend_api()
  end

  test "GET #new shows login form when site and client are found" do
    get new_session_path, params: {
      url: @site.url,
      ssid: @site.ssid,
      id: @client_mac,
      ap: "94:2a:6f:d0:30:57",
      t: Time.current.to_i
    }

    assert_response :success
    assert_select "form"
    assert_select "input[name='name']"
    assert_select "input[type=hidden][name='ssid'][value='thisted-guest']"
    assert_select "input[type=hidden][name='url'][value='https://heimdall.test']"
    assert_select "input[type=hidden][name='id'][value='1c:71:25:63:e4:24']"
    assert_select "input[type=hidden][name='ap'][value='94:2a:6f:d0:30:57']"
  end

  test "POST #create sends OTP and renders OTP form" do
    post session_path, params: {
      name: "Alice",
      pnr: "123456-7890",
      email: "alice@example.com",
      phone: "+4511223344",
      url: @site.url,
      ssid: @site.ssid,
      id: @client_mac,
      ap: "94:2a:6f:d0:30:57",
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match "Indtast koden vi har sendt til dig", @response.body
    assert session[:otp].present?
  end

  test "PATCH #update authenticates and renders success with correct OTP" do
    ActionMailer::Base.deliveries.clear
    otp_code = "123456"

    OtpGenerator.stub(:generate_otp, otp_code) do
      perform_enqueued_jobs do
        post session_path, params: {
          name: "Alice",
          pnr: "123456-7890",
          email: "alice@example.com",
          phone: "+4511223344",
          url: @site.url,
          ssid: @site.ssid,
          id: @client_mac,
          ap: "94:2a:6f:d0:30:57",
        }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end
    end

    assert_equal 1, ActionMailer::Base.deliveries.size

    email = ActionMailer::Base.deliveries.last
    plain_body = email.text_part.body.to_s
    html_body = email.html_part.body.to_s
    assert_equal ["alice@example.com"], email.to
    assert_match /\d{6}/, plain_body || html_body

    patch session_path, 
      params: {
        url: @site.url,
        ssid: @site.ssid,
        id: @client_mac,
        otp: otp_code
      },
      headers: {
        "Accept" => "text/vnd.turbo-stream.html"
      }

    assert_response :success
    assert_match "nu tilsluttet", @response.body
  end

  test "POST #create redirects to OTP path with HTML format" do
    otp_code = "123456"

    post session_path, params: {
      ap: "94:2a:6f:d0:30:57",
      id: "1c:71:25:63:e4:24",
      url: "https://heimdall.test",
      ssid: "thisted-guest",
      t: Time.current.to_i,
      name: "Freelancer",
      pnr: "123456-7890",
      email: "test@example.com",
      phone: "+4512345678"
    }, headers: { "Accept" => "text/html" } # 👈 forces HTML

    assert_response :redirect
    follow_redirect!
    patch session_path, params: {
      otp:  otp_code
    }, 
    headers: {  "Accept" => "text/html" }
    assert_response :redirect
    follow_redirect!
    assert_response :success

  end  

  test "PATCH #update fails with incorrect OTP" do
    # stub_guest_authorization_api

    post session_path, params: {
      name: "Alice",
      pnr: "123456-7890",
      email: "alice@example.com",
      phone: "+4511223344",
      url: @site.url,
      ssid: @site.ssid,
      id: @client_mac,
      ap: "94:2a:6f:d0:30:57",
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }


    patch session_path, params: {
      otp: "111111"
    }, 
    headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match "er forkert eller udløbet", @response.body
  end
end
