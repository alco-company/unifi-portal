# test/controllers/session_controller_test.rb
require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    tenant = tenants(:one)
    @site = sites(:one)
    @client = clients(:one)
    @device = devices(:one)
    @client_mac = @device.mac_address
    @site.unifi_id = "88f7af54-98f8-306a-a1c7-c9349722b1f6"
    stub_unifi_client_api(@client_mac)
    stub_unifi_sites_api(@site.unifi_id)
    stub_guest_authorization_api()
    stub_mailersend_api()
    stub_smsapi(@client.phone.gsub("+", ""), "123456") # Stub the SMS API to return a fixed OTP code - leave out the '+'

  end

  test "GET #new shows login form when site and client are found" do
    get '/guest/s/default', params: {
      url: @site.url,
      ssid: @site.ssid,
      id: @client_mac,
      ap: @device.last_ap,
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
    otp_code = "123456"
    stub_smsapi(otp_code)
    OtpGenerator.stub(:generate_otp, otp_code) do
      post session_path, params: {
        name: "Alice",
        email: "alice@example.com",
        phone: "+4512345678",
        tid: @site.tenant_id,
        sid: @site.id,
        url: @site.url,
        ssid: @site.ssid,
        id: @client_mac,
        ap: @device.last_ap
      }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      assert_response :success
      assert_match "Indtast koden vi har sendt til dig", @response.body
    end  
  end

  test "PATCH #update authenticates and renders success with correct OTP" do
    ActionMailer::Base.deliveries.clear
    otp_code = "123456"
    OtpGenerator.stub(:generate_otp, otp_code) do
      perform_enqueued_jobs do
        post session_path, params: {
          name: "Alice",
          email: @client.email,
          phone: @client.phone,
          tid: @site.tenant_id,
          sid: @site.id,
          url: @site.url,
          ssid: @site.ssid,
          id: @client_mac,
          ap: @device.last_ap
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
        did: @device.id,
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
    OtpGenerator.stub(:generate_otp, otp_code) do
      perform_enqueued_jobs do
        post session_path, params: {
          ap: @device.last_ap,
          id: @client_mac,
          url: @site.url,
          ssid: @site.ssid,
          t: Time.current.to_i,
          name: "Freelancer",
          email: @client.email,
          phone: @client.phone
        }, headers: { "Accept" => "text/html" } # 👈 forces HTML
      end
    end

    assert_response :redirect
    follow_redirect!
    patch session_path, params: {
      did: @device.id,
      otp:  otp_code
    }, 
    headers: {  "Accept" => "text/html" }
    assert_response :redirect
    follow_redirect!
    assert_response :success

  end  

  test "PATCH #update fails with incorrect OTP" do
    # stub_guest_authorization_api
    otp_code = "123456"

    OtpGenerator.stub(:generate_otp, otp_code) do
      post session_path, params: {
        name: "Alice",
        email: @client.email,
        phone: @client.phone,
        url: @site.url,
        ssid: @site.ssid,
        id: @client_mac,
        ap: @device.last_ap,
      }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    patch session_path, params: {
      did: @device.id,
      otp: "111111"
    }, 
    headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match "er forkert eller udløbet", @response.body
  end
end
