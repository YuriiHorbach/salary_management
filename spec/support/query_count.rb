# frozen_string_literal: true

# Counts SQL statements executed inside a block so specs can assert that a
# request or query object does not issue extra statements as the dataset grows.
module QueryCount
  # @param matching [Regexp, String, nil] optional SQL fragment to count only
  # @return [Integer] executed statements, excluding schema and cache lookups
  def count_sql_queries(matching: nil, &)
    count = 0
    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      next if payload[:cached] || payload[:name] == 'SCHEMA'
      next if matching && !payload[:sql].match?(matching)

      count += 1
    end

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record', &)
    count
  end
end

RSpec.configure do |config|
  config.include QueryCount
end
