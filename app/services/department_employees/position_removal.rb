# frozen_string_literal: true

module DepartmentEmployees
  # Removes one position assignment from a single employee inside one department.
  #
  # The service only accepts positions that belong to the given department and
  # only removes the join row for the requested employee, so other employees and
  # assignments in other departments stay untouched. When the removed position
  # was the employee's last one, a positionless +DepartmentEmployee+ row is
  # created so the employee remains a member of the department; when other
  # positions remain, a redundant positionless row is removed.
  #
  # Used by +DepartmentEmployeePositionsController#destroy+.
  class PositionRemoval
    # @param department [Department] department that owns the position
    # @param employee [Employee] employee whose assignment is being removed
    # @param position [Position, nil] position assignment to remove
    # @return [Boolean] true when the assignment was removed, false when the
    #   position is missing, belongs to another department, or is not assigned
    #   to the employee
    def self.call(department:, employee:, position:)
      new(department: department, employee: employee, position: position).call
    end

    def initialize(department:, employee:, position:)
      @department = department
      @employee = employee
      @position = position
    end

    def call
      return false unless position_in_department?

      assignment = find_assignment
      return false unless assignment

      ActiveRecord::Base.transaction do
        assignment.destroy!
        ensure_membership
      end

      true
    end

    private

    def position_in_department?
      return false if @position.blank?

      @department.positions.exists?(id: @position.id)
    end

    def find_assignment
      @department.department_employees.find_by(employee_id: @employee.id, position_id: @position.id)
    end

    def ensure_membership
      assignments = @department.department_employees.where(employee_id: @employee.id)

      if assignments.where.not(position_id: nil).exists?
        assignments.where(position_id: nil).destroy_all
      elsif !assignments.exists?
        assignments.create!(position_id: nil)
      end
    end
  end
end
