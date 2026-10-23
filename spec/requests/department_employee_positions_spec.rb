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

      it 'renders the assigned positions with edit and delete links' do
        create(:department_employee, employee: employee, department: department, position: engineer_position)

        get edit_department_employee_positions_path(department_id: department.id, employee_id: employee.id)

        row = Nokogiri::HTML(response.body).at_css("#assigned_position_#{engineer_position.id}")

        expect(row).to be_present
        expect(row.text).to include('Engineer')
        expect(row.at_css("a[href*='position_id=#{engineer_position.id}']")).to be_present
        expect(row.at_css("a[data-turbo-method='delete']")).to be_present
        expect(response.body).not_to include("assigned_position_#{manager_position.id}")
      end

      it 'highlights the position requested for editing' do
        create(:department_employee, employee: employee, department: department, position: engineer_position)

        get edit_department_employee_positions_path(
          department_id: department.id,
          employee_id: employee.id,
          position_id: engineer_position.id
        )

        highlighted = Nokogiri::HTML(response.body).at_css("#position_label_#{engineer_position.id}.ring-2")

        expect(highlighted).to be_present
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

      it 'keeps the department period and position filter in the forms and links' do
        create(:department_employee, employee: employee, department: department, position: engineer_position)
        get edit_department_employee_positions_path(department_id: department.id, employee_id: employee.id,
                                                    period: '2025-03', position: engineer_position.id)
        page = Nokogiri::HTML(response.body)
        patch_form = page.at_css('form[action*="/employees/"]')
        back_link = page.css('a').find do |link|
          link.text.strip == I18n.t('department_employee_positions.edit.back')
        end
        create_form = page.at_css('input[name="position[position_name]"]').ancestors('form').first
        expect(patch_form['action']).to include('period=2025-03', "position=#{engineer_position.id}")
        expect(back_link['href']).to include('period=2025-03', "position=#{engineer_position.id}")
        expect(create_form.at_css('input[name="return_period"]')['value']).to eq('2025-03')
        expect(create_form.at_css('input[name="return_position"]')['value']).to eq(engineer_position.id.to_s)
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

      it 'preserves the department period and position filter in the redirect' do
        patch department_employee_positions_path(department_id: department.id, employee_id: employee.id),
              params: { position_ids: [engineer_position.id], period: '2025-03',
                        position: engineer_position.id }

        expect(response).to redirect_to(
          department_path(department, period: '2025-03', position: engineer_position.id)
        )
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

  describe 'DELETE /destroy' do
    context 'when authorized' do
      before { sign_in user }

      it 'removes the selected position and redirects to the department' do
        create(:department_employee, employee: employee, department: department, position: manager_position)
        create(:department_employee, employee: employee, department: department, position: engineer_position)

        delete department_employee_positions_path(
          department_id: department.id,
          employee_id: employee.id,
          position_id: manager_position.id
        )

        expect(response).to redirect_to(
          edit_department_employee_positions_path(department_id: department.id, employee_id: employee.id)
        )
        expect(flash[:notice]).to eq(I18n.t('flash.department_employee_positions.deleted'))
        expect(assigned_position_ids).to contain_exactly(engineer_position.id)
      end

      it 'preserves the department period and position filter after deleting a position' do
        create(:department_employee, employee: employee, department: department, position: manager_position)
        delete department_employee_positions_path(department_id: department.id, employee_id: employee.id,
                                                  position_id: manager_position.id, period: '2025-03',
                                                  position: engineer_position.id)
        expect(response).to redirect_to(
          edit_department_employee_positions_path(department_id: department.id, employee_id: employee.id,
                                                  period: '2025-03', position: engineer_position.id)
        )
      end

      it 'keeps the employee in the department when the last position is removed' do
        create(:department_employee, employee: employee, department: department, position: manager_position)

        delete department_employee_positions_path(
          department_id: department.id,
          employee_id: employee.id,
          position_id: manager_position.id
        )

        expect(response).to redirect_to(
          edit_department_employee_positions_path(department_id: department.id, employee_id: employee.id)
        )
        expect(department.employees).to include(employee)
        expect(assigned_position_ids).to eq([nil])
      end

      it 'does not remove a position from another department' do
        create(:department_employee, employee: employee, department: department, position: manager_position)

        delete department_employee_positions_path(
          department_id: department.id,
          employee_id: employee.id,
          position_id: foreign_position.id
        )

        expect(response).to redirect_to(
          edit_department_employee_positions_path(department_id: department.id, employee_id: employee.id)
        )
        expect(flash[:alert]).to eq(I18n.t('flash.department_employee_positions.not_found'))
        expect(assigned_position_ids).to contain_exactly(nil, manager_position.id)
      end

      it 'alerts when the position is not assigned to the employee' do
        delete department_employee_positions_path(
          department_id: department.id,
          employee_id: employee.id,
          position_id: manager_position.id
        )

        expect(response).to redirect_to(
          edit_department_employee_positions_path(department_id: department.id, employee_id: employee.id)
        )
        expect(flash[:alert]).to eq(I18n.t('flash.department_employee_positions.not_found'))
      end

      it 'returns not found when the employee is not a member of the department' do
        outsider = create(:employee)

        delete department_employee_positions_path(
          department_id: department.id,
          employee_id: outsider.id,
          position_id: manager_position.id
        )

        expect(response).to have_http_status(:not_found)
        expect(department.department_employees.where(employee_id: outsider.id)).to be_empty
      end
    end

    context 'when unauthorized' do
      it 'redirects to the login page' do
        delete department_employee_positions_path(
          department_id: department.id,
          employee_id: employee.id,
          position_id: manager_position.id
        )

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  def assigned_position_ids
    department.department_employees.where(employee_id: employee.id).pluck(:position_id)
  end
end
