# frozen_string_literal: true

module ReportsHelper
  START_YEAR = 2000

  def year_options
    (START_YEAR..Time.now.year).to_a.reverse
  end

  def month_options
    (1..12).map { |m| [Date::MONTHNAMES[m], m] }
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

  def detailed_report_cell_value(key, row)
    return row[key] if detailed_report_text_column?(key)

    format('%.2f', row[key])
  end

  private

  def detailed_report_text_column?(key)
    Reports::EmployeeDetailedQuery::TEXT_COLUMNS.include?(key)
  end
end
