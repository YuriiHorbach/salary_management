# frozen_string_literal: true

# View helpers for the bulk employee-assignment page.
module DepartmentEmployeesHelper
  # Builds the link that switches between the full list and pagination while
  # preserving the active search and sort parameters.
  #
  # @param pagination_enabled [Boolean] current mode
  # @param department [Department] department being edited
  # @return [ActiveSupport::SafeBuffer]
  def department_employees_pagination_toggle(pagination_enabled, department)
    target_mode = pagination_enabled ? '0' : '1'
    label = pagination_enabled ? t('department_employees.new.show_all') : t('department_employees.new.paginate')
    query = request.query_parameters.merge(department_id: department.id, paginate: target_mode)

    link_to label, new_department_employee_path(query),
            class: 'inline-block text-sm text-blue-600 hover:underline'
  end

  # Renders pagination only when a Pagy object is present.
  #
  # @param pagy [Pagy, nil]
  # @return [ActiveSupport::SafeBuffer, nil]
  def department_employees_pagination(pagy)
    return unless pagy

    render 'shared/pagination',
           pagy: pagy,
           pagination_id: 'department_employees_pagination',
           margin_class: 'mt-4'
  end

  # Explains that the full list was capped and the search should be narrowed.
  #
  # @param truncated [Boolean]
  # @return [ActiveSupport::SafeBuffer, nil]
  def department_employees_limit_notice(truncated)
    return unless truncated

    tag.p(
      t('department_employees.new.limit_notice', count: DepartmentEmployeesController::MAX_UNPAGINATED_EMPLOYEES),
      class: 'm-5 text-sm text-amber-700'
    )
  end
end
