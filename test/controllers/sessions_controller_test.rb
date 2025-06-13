# test/controllers/session_controller_test.rb
require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @site = Site.create!(controller_url: "https://localhost:3000", url: "https://localhost:3000", ssid: "thisted-guest", api_key: "test-key")
    @client_mac = "1c:71:25:63:e4:24"
    stub_unifi_sites_api
    stub_unifi_client_api(@client_mac)
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
    assert_select "input[name='user[name]']"
    assert_select "input[type=hidden][name='ssid'][value='thisted-guest']"
    assert_select "input[type=hidden][name='url'][value='https://localhost:3000']"
    assert_select "input[type=hidden][name='id'][value='1c:71:25:63:e4:24']"
    assert_select "input[type=hidden][name='ap'][value='94:2a:6f:d0:30:57']"
  end

  test "POST #create sends OTP and renders OTP form" do
    post session_path, params: {
      user: {
        name: "Alice",
        pnr: "123456-7890",
        email: "alice@example.com",
        phone: "+4511223344"
      }
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match "Enter the code we sent you", @response.body
    assert session[:otp].present?
  end

  test "PATCH #update authenticates and renders success with correct OTP" do
    session[:otp] = "654321"
    session[:otp_sent_at] = 1.minute.ago
    session[:client_id] = "test-client-id"

    stub_guest_authorization_api

    patch session_path(), params: {
      otp: "654321"
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match "now connected", @response.body
  end

  test "PATCH #update fails with incorrect OTP" do
    session[:otp] = "654321"
    session[:otp_sent_at] = 1.minute.ago

    patch session_path, params: {
      otp: "111111"
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match "Invalid code", @response.body
  end
end
