# frozen_string_literal: true

# Monthly vacation report grouped by employee.
#
# Aggregation is delegated to +Vacation.report_rows_for_month+ and employees are
# preloaded in one query, keeping the controller thin and the view free of N+1.
class VacationReportsController < ApplicationController
  before_action :authenticate_user!

  def index
    load_report
    render partial: 'vacation_reports/frame' if turbo_frame_request?
  end

  private

  def load_report
    @month = selected_month
    @report_rows = Vacation.report_rows_for_month(@month)
    @employees_by_id = Employee.where(id: @report_rows.map(&:employee_id)).index_by(&:id)
    @report_rows = @report_rows.sort_by { |row| @employees_by_id[row.employee_id]&.full_name.to_s }
    @total_vacation_cents = @report_rows.sum(&:vacation_cents)
    @total_income_tax_cents = @report_rows.sum(&:income_tax_cents)
    @total_military_tax_cents = @report_rows.sum(&:military_tax_cents)
    @total_net_cents = @report_rows.sum(&:net_cents)
  end

  # @return [String] canonical +YYYY-MM+ month, falling back to the working month
  def selected_month
    (Reports::Period.parse(params[:month]) || Reports::Period.from_date(current_working_month)).to_s
  end
end
