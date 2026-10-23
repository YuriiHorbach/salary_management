# frozen_string_literal: true

require 'rails_helper'

# Covers the position management flow: the department page only links to the
# employee's positions page, while editing and deleting individual positions
# happens on that page.
RSpec.describe 'Department employee positions', :js, type: :system do
  let(:user) { create(:user) }
  let(:department) { create(:department) }
  let(:employee) do
    create(:employee, last_name: 'Kovalenko', first_name: 'Iryna', patronic_name: 'Petrivna')
  end
  let!(:manager_position) { create(:position, department: department, position_name: 'Manager') }
  let!(:engineer_position) { create(:position, department: department, position_name: 'Engineer') }

  before do
    create(:department_employee, employee: employee, department: department, position: manager_position)
    login_as user, scope: :user
    visit department_path(department)
  end

  it 'opens the employee positions page when a position name is clicked' do
    within("#department_employee_#{employee.id}") do
      click_link 'Manager'
    end

    expect(page).to have_current_path(
      edit_department_employee_positions_path(department_id: department.id, employee_id: employee.id),
      ignore_query: true
    )
    expect(page).to have_css("#assigned_position_#{manager_position.id}")
  end

  it 'replaces the employee position from the edit form' do
    within("#department_employee_#{employee.id}") do
      click_link 'Manager'
    end

    uncheck "position_#{manager_position.id}"
    check "position_#{engineer_position.id}"
    click_button I18n.t('department_employee_positions.edit.save')

    expect(page).to have_current_path(department_path(department), ignore_query: true)

    within("#department_employee_#{employee.id}") do
      expect(page).to have_text('Engineer')
      expect(page).not_to have_text('Manager')
    end
  end

  it 'highlights the editable position when its edit link is clicked' do
    visit edit_department_employee_positions_path(department_id: department.id, employee_id: employee.id)

    within("#assigned_position_#{manager_position.id}") do
      click_link I18n.t('department_employee_positions.edit.edit')
    end

    expect(page).to have_css("#position_label_#{manager_position.id}.ring-2")
  end

  it 'deletes a single position and keeps the other one' do
    create(:department_employee, employee: employee, department: department, position: engineer_position)
    visit edit_department_employee_positions_path(department_id: department.id, employee_id: employee.id)

    delete_position(manager_position)

    expect(page).to have_current_path(
      edit_department_employee_positions_path(department_id: department.id, employee_id: employee.id),
      ignore_query: true
    )
    expect(page).not_to have_css("#assigned_position_#{manager_position.id}")
    expect(page).to have_css("#assigned_position_#{engineer_position.id}")
  end

  it 'keeps the employee in the department after deleting the last position' do
    visit edit_department_employee_positions_path(department_id: department.id, employee_id: employee.id)
    delete_position(manager_position)
    expect(page).to have_current_path(
      edit_department_employee_positions_path(department_id: department.id, employee_id: employee.id),
      ignore_query: true
    )
    expect(page).to have_text(I18n.t('department_employee_positions.edit.empty'))
    visit department_path(department)

    within("#department_employee_#{employee.id}") do
      expect(page).to have_text('Kovalenko')
      expect(page).to have_link(I18n.t('departments.show.add_position'))
      expect(page).not_to have_text('Manager')
    end

    expect(department.department_employees.find_by(employee_id: employee.id).position_id).to be_nil
  end

  def delete_position(position)
    within("#assigned_position_#{position.id}") do
      accept_confirm { click_link I18n.t('department_employee_positions.edit.delete') }
    end
  end
end
