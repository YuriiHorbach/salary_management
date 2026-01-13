# frozen_string_literal: true

require 'spec_helper'

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'
require 'factory_bot'
require 'action_text/system_test_helper'

Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!

  config.include Rails.application.routes.url_helpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :request

  config.include ActiveJob::TestHelper
  config.before(:each, type: :job) do
    ActiveJob::Base.queue_adapter = :test
  end

  config.before(:each, type: :request) do
    host! '127.0.0.1'
    ActionController::Base.allow_forgery_protection = false
  end

  config.use_transactional_fixtures = false

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning { example.run }
  end

  config.filter_rails_from_backtrace!

  config.before(:suite) { $VERBOSE = nil }
  config.after(:suite) { $VERBOSE = true }
end
