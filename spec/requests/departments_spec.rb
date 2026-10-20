# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Departments', type: :request do
  let(:user) { create :user }

  def rendered_last_names
    Nokogiri::HTML(response.body)
            .css('tbody tr')
            .filter_map { |row| row.css('td')[1]&.text&.strip }
  end

  describe 'GET /index' do
    context 'when user is authorized' do
      it 'shows a departments list' do
        sign_in(user)
        get departments_path

        expect(response).to be_successful
      end
    end

    context 'when admin unauthorized' do
      it 'does not see users list' do
        get departments_path
        expect(response).to redirect_to(user_session_path)
      end
    end
  end

  describe 'GET /show' do
    context 'when authorized' do
      let(:department) { create(:department) }
      let!(:alpha) do
        create(:employee, id_code: '1000000001', last_name: 'Alpha', first_name: 'Anna', patronic_name: 'Andriivna')
      end
      let!(:zeta) do
        create(:employee, id_code: '9000000002', last_name: 'Zeta', first_name: 'Zoe', patronic_name: 'Zakharivna')
      end

      before do
        department.employees << [zeta, alpha]
        sign_in(user)
      end

      it 'shows a department page' do
        get department_path(department.id)

        expect(response).to be_successful
      end

      it 'sorts employees by last name ascending' do
        get department_path(department, q: { s: 'last_name asc' })

        expect(response).to be_successful
        expect(rendered_last_names).to eq(%w[Alpha Zeta])
      end

      it 'sorts employees by last name descending' do
        get department_path(department, q: { s: 'last_name desc' })

        expect(rendered_last_names).to eq(%w[Zeta Alpha])
      end

      it 'sorts employees by id code' do
        get department_path(department, q: { s: 'id_code desc' })

        expect(rendered_last_names).to eq(%w[Zeta Alpha])
      end

      it 'only renders employees that belong to the department' do
        create(:employee, id_code: '5000000003', last_name: 'Outsider', first_name: 'Olha', patronic_name: 'Olehivna')

        get department_path(department)

        expect(rendered_last_names).to contain_exactly('Alpha', 'Zeta')
        expect(response.body).not_to include('Outsider')
      end

      it 'renders sortable headers for the employee columns' do
        get department_path(department)

        headers = Nokogiri::HTML(response.body).css('thead th a')

        expect(headers.map(&:text)).to include('ID', 'Last name', 'First name', 'Patronic name')
        expect(headers.map { |link| link['href'] }).to all(include('q%5Bs%5D'))
      end
    end

    context 'when unauthorized' do
      it 'redirect to the root_path' do
        department = create(:department)
        get department_path(department.id)

        expect(response).to redirect_to(user_session_path)
      end
    end
  end
end
