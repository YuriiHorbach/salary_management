# frozen_string_literal: true

# Builds sortable header links for department columns whose ordering is applied
# by +DepartmentEmployeeSortQuery+ instead of Ransack. The links still use
# Ransack's +q[s]+ parameter so standard and custom columns replace each other
# rather than stacking multiple sort values.
module DepartmentsHelper
  # @param column [String] custom sort column ("position" or "salary")
  # @param label [String] visible header label
  # @param department [Department] department being rendered
  # @return [ActiveSupport::SafeBuffer] link preserving the current filters
  def department_custom_sort_link(column, label, department)
    direction = params.dig(:q, :s).to_s == "#{column} asc" ? 'desc' : 'asc'
    url = department_path(
      department,
      request.query_parameters.deep_merge('q' => { 's' => "#{column} #{direction}" })
    )

    link_to safe_join([label, department_sort_indicator(column)].compact, ' '), url
  end

  private

  def department_sort_indicator(column)
    current_sort = params.dig(:q, :s).to_s
    if current_sort == "#{column} asc"
      '▼'
    elsif current_sort == "#{column} desc"
      '▲'
    end
  end
end
