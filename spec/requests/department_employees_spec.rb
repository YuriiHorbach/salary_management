# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'DepartmentEmployees', type: :request do
  include Rails.application.routes.url_helpers

  let(:user) { create(:user) }
  let(:employee1) { create(:employee) }
  let(:employee2) { create(:employee) }
  let(:department) { create(:department) }

  describe 'POST /department_employees' do
    context "when authorized" do
      before { sign_in user }

      it "successfully adds employees to the department" do
        post department_employees_path, params: { 
          department_id: department.id,
          employee_ids: [employee1.id, employee2.id]
        }
        expect(response).to redirect_to(department_path(department))
      end

      it "removes employee from department" do
        department.employees << employee1
        delete remove_department_employee_path(department, employee1)
        
        expect(department.employees.exists?(employee1.id)).to be_falsy
        expect(response).to redirect_to(department_path(department))
      end
    end
  
    context "when unauthorized" do
      it "redirects to the login page" do
        post department_employees_path, params: { 
          department_id: department.id,
          employee_ids: [employee1.id]
        }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
