# frozen_string_literal: true

# Monthly sick day report grouped by employee.
#
# Aggregation is delegated to +SickDay.report_for_month+ and employees are
# preloaded in one query, keeping the controller thin and the view free of N+1.
class SickDayReportsController < ApplicationController
  before_action :authenticate_user!

  def index
    load_report
    render partial: 'sick_day_reports/frame' if turbo_frame_request?
  end

  private

  def load_report
    @month = selected_month
    @report_rows = SickDay.report_rows_for_month(@month)
    @employees_by_id = Employee.where(id: @report_rows.map(&:employee_id)).index_by(&:id)
    @report_rows = @report_rows.sort_by { |row| @employees_by_id[row.employee_id]&.full_name.to_s }
    @total_pfu_cents = @report_rows.sum(&:pfu_cents)
    @total_enterprise_cents = @report_rows.sum(&:enterprise_cents)
    @total_cents = @report_rows.sum(&:total_cents)
  end

  # @return [String] canonical +YYYY-MM+ month, falling back to the working month
  def selected_month
    (Reports::Period.parse(params[:month]) || Reports::Period.from_date(current_working_month)).to_s
  end
end
