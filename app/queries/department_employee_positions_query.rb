# frozen_string_literal: true

# Builds the positions displayed for employees in a department.
#
# The result combines positions explicitly assigned through
# +DepartmentEmployee+ with positions referenced by salary rows for the selected
# period. Including salary positions keeps historical salaries visible even when
# the assignment was removed. A position filter is applied to both sources, so
# +period_salaries+ does not need to be pre-filtered by the caller.
class DepartmentEmployeePositionsQuery
  # @param department [Department] department whose positions are loaded
  # @param employee_ids [Array<Integer>] employees currently rendered
  # @param period_salaries [Hash{Array(Integer, Integer, nil) => Integer}]
  #   salary amounts keyed by +[employee_id, position_id]+
  # @param position [Position, Integer, nil] optional position filter
  def initialize(department, employee_ids:, period_salaries:, position: nil)
    @department = department
    @employee_ids = Array(employee_ids)
    @period_salaries = period_salaries || {}
    @position = position
  end

  # @return [Hash{Integer => Array<Position>}] positions sorted by name
  def call
    grouped = assigned_positions_by_employee
    merge_salary_positions!(grouped)
    grouped.transform_values { |positions| positions.sort_by(&:position_name) }
  end

  private

  def assigned_positions_by_employee
    assignments = @department.department_employees.where(employee_id: @employee_ids)
    assignments = assignments.where(position_id: position_id) if position_id.present?
    assignments.includes(:position)
               .group_by(&:employee_id)
               .transform_values { |rows| rows.filter_map(&:position).uniq }
  end

  def merge_salary_positions!(grouped)
    scope = @department.positions.where(id: salary_position_ids)
    scope = scope.where(id: position_id) if position_id.present?

    salary_positions = scope.index_by(&:id)

    @period_salaries.each_key do |employee_id, position_id|
      next unless @employee_ids.include?(employee_id)
      next if position_id.blank?

      position = salary_positions[position_id]
      next unless position

      employee_positions = grouped[employee_id] ||= []
      employee_positions << position unless employee_positions.any? { |existing| existing.id == position.id }
    end
  end

  def salary_position_ids
    @period_salaries.keys.filter_map do |employee_id, position_id|
      position_id if @employee_ids.include?(employee_id) && position_id.present?
    end.uniq
  end

  def position_id
    @position.is_a?(Position) ? @position.id : @position
  end
end
