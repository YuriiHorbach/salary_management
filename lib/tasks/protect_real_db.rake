# frozen_string_literal: true

# Захист від випадкового стирання реальної бази: деструктивні db:* задачі відмовляють,
# якщо назва бази не закінчується на _agent або _test.
# Свідоме виконання: CONFIRM_ERASE_DATABASE=1 bin/rails db:...
# db:prepare та db:migrate цим не охоплені навмисно.
namespace :guard do
  desc 'Abort when a destructive task targets a database that is not an agent/test database'
  task real_db: :environment do
    database = ActiveRecord::Base.connection_db_config.database
    next if database.to_s.match?(/_(agent|test)\z/) || ENV['CONFIRM_ERASE_DATABASE'] == '1'

    abort "Відмова: ця команда стирає дані в базі '#{database}'. " \
          'Якщо це свідомо, повторіть з CONFIRM_ERASE_DATABASE=1.'
  end
end

%w[db:schema:load db:drop db:reset db:setup db:purge db:migrate:reset db:truncate_all].each do |name|
  Rake::Task[name].enhance(['guard:real_db']) if Rake::Task.task_defined?(name)
end
