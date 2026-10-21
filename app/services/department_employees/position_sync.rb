# frozen_string_literal: true

module DepartmentEmployees
  # Synchronizes the positions assigned to a single employee inside one department.
  #
  # It accepts the position ids submitted by the per-employee positions form,
  # rejects positions that belong to another department, and creates or removes
  # +DepartmentEmployee+ join rows so the employee ends up with exactly the
  # selected positions. When no positions remain selected the employee stays in
  # the department through a positionless join row, so removing positions never
  # removes the department membership.
  #
  # Used by +DepartmentEmployeePositionsController#update+.
  class PositionSync
    # @param department [Department] department that owns the allowed positions
    # @param employee [Employee] employee whose positions are being synced
    # @param position_ids [Array<Integer, String>] submitted position ids
    # @return [Boolean] true when assignments were synced, false when only
    #   positions from another department were submitted and nothing changed
    def self.call(department:, employee:, position_ids:)
      new(department: department, employee: employee, position_ids: position_ids).call
    end

    def initialize(department:, employee:, position_ids:)
      @department = department
      @employee = employee
      @position_ids = normalize_position_ids(position_ids)
    end

    def call
      valid_ids = valid_position_ids
      return false if invalid_only?(valid_ids)

      ActiveRecord::Base.transaction { sync_assignments(valid_ids) }
      true
    end

    private

    def normalize_position_ids(position_ids)
      Array(position_ids).filter_map { |id| Integer(id.to_s, exception: false) }.uniq
    end

    def valid_position_ids
      @department.positions.where(id: @position_ids).pluck(:id)
    end

    def invalid_only?(valid_ids)
      @position_ids.any? && valid_ids.empty?
    end

    def sync_assignments(position_ids)
      assignments = @department.department_employees.where(employee_id: @employee.id)

      position_ids.empty? ? clear_positions(assignments) : assign_positions(assignments, position_ids)
    end

    def clear_positions(assignments)
      assignments.where.not(position_id: nil).destroy_all
      assignments.create!(position_id: nil) unless assignments.exists?
    end

    def assign_positions(assignments, position_ids)
      assignments.where(position_id: nil).destroy_all
      assignments.where.not(position_id: position_ids).destroy_all

      existing_ids = assignments.where(position_id: position_ids).pluck(:position_id)
      (position_ids - existing_ids).each { |position_id| assignments.create!(position_id: position_id) }
    end
  end
end
