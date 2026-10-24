# frozen_string_literal: true

# Sorts department employees by columns that cannot use a plain Ransack sort.
#
# Position ordering depends on the positions displayed for the selected period
# and filter, while salary ordering depends on the salary total for the selected
# period. Both values are already loaded by +DepartmentsController#show+, so
# sorting happens in memory without extra queries. Standard employee columns
# continue to use Ransack.
class DepartmentEmployeeSortQuery
  SUPPORTED_ATTRIBUTES = %w[position salary].freeze
  DIRECTIONS = %w[asc desc].freeze

  # @param employees [Array<Employee>] employees currently rendered
  # @param sort [String, nil] Ransack-style sort, for example "position asc"
  # @param positions_by_employee [Hash{Integer => Array<Position>}]
  # @param salary_totals [Hash{Integer => Integer}] salary cents by employee
  def initialize(employees, sort:, positions_by_employee:, salary_totals:)
    @employees = Array(employees)
    @sort = parse_sort(sort)
    @positions_by_employee = positions_by_employee || {}
    @salary_totals = salary_totals || {}
  end

  # @return [Array<Employee>] sorted employees, or the original order when the
  #   sort is not handled by this query
  def call
    return @employees unless @sort

    attribute, direction = @sort
    @employees.sort { |left, right| compare(left, right, attribute, direction) }
  end

  # Returns whether the sort is handled by this query.
  #
  # @param sort [String, nil] Ransack-style sort
  # @return [Boolean]
  def self.custom_sort?(sort)
    attribute, direction = sort.to_s.split
    return false unless SUPPORTED_ATTRIBUTES.include?(attribute)

    direction.blank? || DIRECTIONS.include?(direction)
  end

  private

  def parse_sort(sort)
    return unless self.class.custom_sort?(sort)

    attribute, direction = sort.to_s.split
    [attribute, direction.presence || 'asc']
  end

  def compare(left, right, attribute, direction)
    result = primary_value(left, attribute) <=> primary_value(right, attribute)
    result = -result if direction == 'desc'
    result.zero? ? name_key(left) <=> name_key(right) : result
  end

  def primary_value(employee, attribute)
    case attribute
    when 'position' then position_label(employee)
    when 'salary' then @salary_totals.fetch(employee.id, 0)
    end
  end

  def position_label(employee)
    @positions_by_employee.fetch(employee.id, []).map(&:position_name).join(', ')
  end

  def name_key(employee)
    [employee.last_name.to_s, employee.first_name.to_s, employee.id]
  end
end
