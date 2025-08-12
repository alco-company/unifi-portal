ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require_relative "support/unifi_api_stubs"
require_relative "support/unifi_login_stubs"
require_relative "support/mailersend_api_stubs"
require_relative "support/smsapi_stubs"
require "rails/test_help"
require "webmock/minitest"
require "minitest/mock"
WebMock.disable_net_connect!(allow_localhost: true)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    include UnifiApiStubs
    include MailersendApiStubs
    include SmsapiStubs


    def login_as(user)
      if respond_to?(:post)
        post admin_login_path, params: { email: user.email, password: "password" }
      else
        raise "login_as not implemented for this type of test"
      end
    end
  end
end
