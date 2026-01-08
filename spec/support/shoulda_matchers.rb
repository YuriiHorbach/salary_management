require 'shoulda/matchers' # Явно підключаємо бібліотеку

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
