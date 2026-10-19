# frozen_string_literal: true

require 'capybara/rspec'
require 'selenium-webdriver'

Capybara.register_driver :chrome_headless do |app|
  options = ::Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--disable-gpu')
  options.add_argument('--window-size=1400,900')
  options.binary = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.default_driver = :rack_test
Capybara.javascript_driver = :chrome_headless
Capybara.default_max_wait_time = 5

Capybara.server = :puma, { Silent: true }

RSpec.configure do |config|
  config.include Capybara::DSL, type: :system
  config.include Capybara::RSpecMatchers, type: :system
  config.include Warden::Test::Helpers, type: :system

  config.before(:each, type: :system) do
    driven_by :chrome_headless
  end

  config.after(:each, type: :system) do
    Warden.test_reset!
  end
end
