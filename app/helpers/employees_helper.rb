# frozen_string_literal: true

# Builds sortable header links for employee salary summaries whose totals are
# calculated in Ruby instead of Ransack.
module EmployeesHelper
  # Builds a sort link for the monthly salary summary table while preserving
  # the current salary filters and locale.
  #
  # @param employee [Employee] employee whose summary is rendered
  # @param column [Symbol, String] summary column, either +month+ or +amount+
  # @param label [String] visible header label
  # @return [ActiveSupport::SafeBuffer] link to the toggled sort order
  def monthly_totals_sort_link(employee, column, label)
    column = column.to_s
    current_column, current_direction = current_monthly_sort.split('_', 2)
    direction = current_column == column && current_direction == 'asc' ? 'desc' : 'asc'
    path = employee_path(
      employee,
      request.query_parameters.deep_merge('monthly_sort' => "#{column}_#{direction}")
    )

    link_to safe_join([label, monthly_totals_sort_indicator(column)].compact, ' '), path
  end

  private

  # @param column [String] summary column being rendered
  # @return [String, nil] arrow for the active column
  def monthly_totals_sort_indicator(column)
    current_column, current_direction = current_monthly_sort.split('_', 2)
    return unless current_column == column

    current_direction == 'desc' ? '▼' : '▲'
  end

  # @return [String] requested sort or the controller default
  def current_monthly_sort
    requested = params[:monthly_sort].to_s
    return requested if EmployeesController::MONTHLY_SORT_OPTIONS.key?(requested)

    EmployeesController::DEFAULT_MONTHLY_SORT
  end
end
