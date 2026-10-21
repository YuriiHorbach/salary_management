# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DepartmentEmployeePositions', type: :request do
  let(:user) { create(:user) }
  let(:department) { create(:department) }
  let(:other_department) { create(:department) }
  let(:employee) { create(:employee) }
  let!(:manager_position) { create(:position, department: department, position_name: 'Manager') }
  let!(:engineer_position) { create(:position, department: department, position_name: 'Engineer') }
  let!(:foreign_position) { create(:position, department: other_department, position_name: 'Foreign') }

  before do
    create(:department_employee, employee: employee, department: department)
  end

  describe 'GET /edit' do
    context 'when authorized' do
      before { sign_in user }

      it 'renders the position selector for the department' do
        get edit_department_employee_positions_path(department_id: department.id, employee_id: employee.id)

        doc = Nokogiri::HTML(response.body)
        values = doc.css('input[name="position_ids[]"]').map { |input| input['value'] }

        expect(response).to have_http_status(:ok)
        expect(values).to contain_exactly(manager_position.id.to_s, engineer_position.id.to_s)
        expect(response.body).not_to include(foreign_position.position_name)
      end

      it 'marks the positions already assigned to the employee' do
        create(:department_employee, employee: employee, department: department, position: engineer_position)

        get edit_department_employee_positions_path(department_id: department.id, employee_id: employee.id)

        checked = Nokogiri::HTML(response.body)
                          .css('input[name="position_ids[]"][checked]')
                          .map { |input| input['value'] }

        expect(checked).to contain_exactly(engineer_position.id.to_s)
      end

      it 'pre-selects a newly created position' do
        get edit_department_employee_positions_path(
          department_id: department.id,
          employee_id: employee.id,
          new_position_id: engineer_position.id
        )

        checked = Nokogiri::HTML(response.body)
                          .css('input[name="position_ids[]"][checked]')
                          .map { |input| input['value'] }

        expect(checked).to contain_exactly(engineer_position.id.to_s)
      end

      it 'returns not found when the employee is not a member of the department' do
        outsider = create(:employee)

        get edit_department_employee_positions_path(department_id: department.id, employee_id: outsider.id)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when unauthorized' do
      it 'redirects to the login page' do
        get edit_department_employee_positions_path(department_id: department.id, employee_id: employee.id)

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'PATCH /update' do
    context 'when authorized' do
      before { sign_in user }

      it 'saves the selected positions and redirects to the department' do
        patch department_employee_positions_path(department_id: department.id, employee_id: employee.id),
              params: { position_ids: [manager_position.id, engineer_position.id] }

        expect(response).to redirect_to(department_path(department))
        expect(assigned_position_ids).to contain_exactly(manager_position.id, engineer_position.id)
      end

      it 'removes positions that were unchecked' do
        create(:department_employee, employee: employee, department: department, position: manager_position)

        patch department_employee_positions_path(department_id: department.id, employee_id: employee.id),
              params: { position_ids: [engineer_position.id] }

        expect(assigned_position_ids).to contain_exactly(engineer_position.id)
      end

      it 'keeps the employee in the department when no positions are selected' do
        create(:department_employee, employee: employee, department: department, position: manager_position)

        patch department_employee_positions_path(department_id: department.id, employee_id: employee.id),
              params: { position_ids: [] }

        expect(response).to redirect_to(department_path(department))
        expect(department.employees).to include(employee)
        expect(assigned_position_ids).to eq([nil])
      end

      it 'ignores positions that belong to another department' do
        patch department_employee_positions_path(department_id: department.id, employee_id: employee.id),
              params: { position_ids: [foreign_position.id] }

        expect(response).to redirect_to(department_path(department))
        expect(assigned_position_ids).to eq([nil])
      end

      it 'returns not found when the employee is not a member of the department' do
        outsider = create(:employee)

        patch department_employee_positions_path(department_id: department.id, employee_id: outsider.id),
              params: { position_ids: [manager_position.id] }

        expect(response).to have_http_status(:not_found)
        expect(department.department_employees.where(employee_id: outsider.id)).to be_empty
      end
    end

    context 'when unauthorized' do
      it 'redirects to the login page' do
        patch department_employee_positions_path(department_id: department.id, employee_id: employee.id),
              params: { position_ids: [manager_position.id] }

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  def assigned_position_ids
    department.department_employees.where(employee_id: employee.id).pluck(:position_id)
  end
end
