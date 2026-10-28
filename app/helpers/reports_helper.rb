# frozen_string_literal: true

module ReportsHelper
  START_YEAR = 2000
  PAGE_NUMBER_OPTIONS = (1..100)

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

  # Builds the numeric options for the inline page-number selector, including a
  # current value that may be outside the default range after a manual import.
  #
  # @param row [Hash] one employee row produced by the detailed query
  # @return [Array<Integer>] available page numbers in ascending order
  def detailed_report_page_number_options(row)
    numbers = PAGE_NUMBER_OPTIONS.to_a
    current = detailed_report_page_number_value(row)
    numbers |= [current] if current && numbers.exclude?(current)
    numbers.sort
  end

  # Returns the numeric part of a combined page number such as +2-О21+.
  #
  # @param row [Hash] one employee row produced by the detailed query
  # @return [Integer, nil] selected page number when the stored value is valid
  def detailed_report_page_number_value(row)
    number = row[:page_number].to_s.split('-', 2).first.to_s
    number.to_i if number.match?(/\A\d+\z/)
  end

  # Stable DOM id used by the inline form and its Turbo Stream replacement.
  #
  # @param row [Hash] one employee row produced by the detailed query
  # @return [String] Turbo Frame id for the page-number cell
  def detailed_report_page_number_frame_id(row)
    "employee_page_number_#{row[:employee_id]}"
  end

  private

  def detailed_report_text_column?(key)
    Reports::EmployeeDetailedQuery::TEXT_COLUMNS.include?(key)
  end
end
