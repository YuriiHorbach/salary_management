# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DepartmentPositions', type: :request do
  let(:user) { create(:user) }
  let(:department) { create(:department) }
  let(:employee) { create(:employee) }

  before do
    create(:department_employee, employee: employee, department: department)
  end

  describe 'POST /departments/:department_id/positions' do
    context 'when authorized' do
      before { sign_in user }

      it 'creates a position in the current department' do
        post department_positions_path(department_id: department.id), params: {
          position: { position_name: 'Manager' },
          employee_id: employee.id
        }

        position = department.positions.find_by(position_name: 'Manager')

        expect(position).to be_present
      end

      it 'returns to the employee positions page after creating a position' do
        post department_positions_path(department_id: department.id), params: {
          position: { position_name: 'Manager' },
          employee_id: employee.id
        }

        expect(response).to redirect_to(
          edit_department_employee_positions_path(
            department_id: department.id,
            employee_id: employee.id,
            new_position_id: Position.last.id
          )
        )
      end

      it 'preserves the department period and position filter after creating a position' do
        post department_positions_path(department_id: department.id),
             params: { position: { position_name: 'Manager' }, employee_id: employee.id,
                       return_period: '2025-03', return_position: 123 }
        expect(response).to redirect_to(
          edit_department_employee_positions_path(department_id: department.id, employee_id: employee.id,
                                                  new_position_id: Position.last.id, period: '2025-03',
                                                  position: 123)
        )
      end

      it 'returns to the department page when employee_id is missing' do
        post department_positions_path(department_id: department.id), params: {
          position: { position_name: 'Manager' }
        }

        expect(response).to redirect_to(department_path(department))
      end

      it 'does not create a position with a blank name' do
        expect do
          post department_positions_path(department_id: department.id), params: {
            position: { position_name: '' },
            employee_id: employee.id
          }
        end.not_to change(Position, :count)

        expect(response).to redirect_to(
          edit_department_employee_positions_path(department_id: department.id, employee_id: employee.id)
        )
      end

      it 'returns to the department page when employee_id does not belong to the department' do
        outsider = create(:employee)

        post department_positions_path(department_id: department.id), params: {
          position: { position_name: 'Manager' },
          employee_id: outsider.id
        }

        expect(response).to redirect_to(department_path(department))
      end
    end

    context 'when unauthorized' do
      it 'redirects to the login page' do
        post department_positions_path(department_id: department.id), params: {
          position: { position_name: 'Manager' }
        }

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
