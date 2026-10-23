# frozen_string_literal: true

module ReportsHelper
  START_YEAR = 2000

  DETAILED_FILTER_PARAMS = %i[
    date_from date_to department brigade account_book employee_search position
  ].freeze

  # Builds the detailed report CSV path, keeping the active filters as query
  # parameters while forcing Rails to render the format as a `.csv` extension.
  def detailed_report_csv_path(params)
    filters = params.permit(*DETAILED_FILTER_PARAMS).to_h
    path = detailed_reports_path(format: :csv)

    filters.present? ? "#{path}?#{filters.to_query}" : path
  end

  def year_options
    (START_YEAR..Time.now.year).to_a.reverse
  end

  # Builds the month filter options using the active locale's month names.
  def month_options
    I18n.t('date.month_names').each_with_index.filter_map do |name, index|
      [name, index] if index.positive?
    end
  end

  def detailed_report_cell_class(key, emphasize: true)
    classes = %w[border border-gray-300 px-3 py-2]
    classes << 'text-right' unless detailed_report_text_column?(key)
    classes << 'text-sm'
    if emphasize
      classes << 'font-medium' if key == :full_name
      classes << 'font-semibold' if key == :net_pay
    end
    classes.join(' ')
  end

  # @param key [Symbol] column key from Reports::EmployeeDetailedQuery
  # @param row [Hash] one employee row produced by the query
  # @return [String, ActiveSupport::SafeBuffer] formatted value; the +id_code+
  #   column is rendered as a link to the employee's salary page
  def detailed_report_cell_value(key, row)
    return detailed_report_id_code_link(row) if key == :id_code
    return row[key] if detailed_report_text_column?(key)

    number_with_precision(row[key], precision: 2)
  end

  # The detailed table is wrapped in a Turbo Frame, so the link has to target the
  # top-level document. Without +turbo_frame: '_top'+ Turbo would try to render
  # the salary page inside the report frame.
  def detailed_report_id_code_link(row)
    link_to row[:id_code], employee_salaries_path(row[:employee_id]),
            class: 'text-blue-600 hover:text-blue-800 underline',
            data: { turbo_frame: '_top' }
  end

  private

  def detailed_report_text_column?(key)
    Reports::EmployeeDetailedQuery::TEXT_COLUMNS.include?(key)
  end
end
