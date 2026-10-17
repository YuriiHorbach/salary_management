# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Main navigation menu', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe 'reports dropdown consolidation' do
    it 'does not render standalone Зведений звіт link in the main nav' do
      get root_path

      expect(response.body).not_to include(%{<a href="/reports/summary" class="hover:text-blue-200">Зведений звіт</a>})
    end

    it 'does not render standalone Детальний звіт link in the main nav' do
      get root_path

      expect(response.body).not_to include(%{<a href="/reports/detailed" class="hover:text-blue-200">Детальний звіт</a>})
    end

    it 'renders a single Звіти dropdown trigger in the main nav' do
      get root_path

      expect(response.body).to include('Звіти')
    end

    it 'renders Зведений звіт sub-link inside the Звіти dropdown' do
      get root_path

      expect(response.body).to include('Зведений звіт')
      expect(response.body).to include('/reports/summary')
    end

    it 'renders Детальний звіт sub-link inside the Звіти dropdown' do
      get root_path

      expect(response.body).to include('Детальний звіт')
      expect(response.body).to include('/reports/detailed')
    end

    it 'renders Stimulus dropdown controller on details elements' do
      get root_path

      expect(response.body).to include('data-controller="dropdown"')
    end
  end
end
