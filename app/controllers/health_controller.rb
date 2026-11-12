# frozen_string_literal: true

# Readiness probe used by the Docker healthcheck and the Electron desktop shell.
#
# Returns +200 OK+ only when PostgreSQL answers a trivial query, so the desktop
# window is not opened before the database is actually usable. Inherits from
# +ActionController::Base+ on purpose: locale resolution and authentication are
# not needed and would add their own database dependencies.
class HealthController < ActionController::Base # rubocop:disable Rails/ApplicationController
  # @return [void]
  def show
    ActiveRecord::Base.connection.select_value('SELECT 1')
    render plain: 'OK'
  rescue StandardError => e
    Rails.logger.error("Health check failed: #{e.class}: #{e.message}")
    render plain: 'FAIL', status: :service_unavailable
  end
end
