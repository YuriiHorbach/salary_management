# frozen_string_literal: true

# require 'factory_bot_rails' # Видалено, бо підключення йде через Gemfile/bundle
require 'factory_bot'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
