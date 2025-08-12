# require "test_helper"

# class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
#   driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
# end
require "test_helper"
require "test_helpers/capybara_setup"
require "test_helpers/cuprite_helpers"
require "test_helpers/cuprite_setup"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :cuprite, using: :chromium, screen_size: [ 1400, 1400 ], options: {
    js_errors: true,
    slowmo: ENV["SLOWMO"]&.to_f
   }

  include CupriteHelpers
  def login_as(user)
    visit admin_login_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "secret"
  click_button "Login"
  end
end
