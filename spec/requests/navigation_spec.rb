# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Main navigation menu', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe 'reports dropdown consolidation' do
    it 'does not render a standalone summary report link in the main nav' do
      get root_path

      standalone = %{<a href="/reports/summary" class="hover:text-blue-200">#{I18n.t('navigation.summary_report')}</a>}

      expect(response.body).not_to include(standalone)
    end

    it 'does not render a standalone detailed report link in the main nav' do
      get root_path

      label = I18n.t('navigation.detailed_report')
      standalone = %{<a href="/reports/detailed" class="hover:text-blue-200">#{label}</a>}

      expect(response.body).not_to include(standalone)
    end

    it 'renders a single reports dropdown trigger in the main nav' do
      get root_path

      expect(response.body).to include(I18n.t('navigation.reports'))
    end

    it 'renders the summary report sub-link inside the reports dropdown' do
      get root_path

      expect(response.body).to include(I18n.t('navigation.summary_report'))
      expect(response.body).to include('/reports/summary')
    end

    it 'renders the detailed report sub-link inside the reports dropdown' do
      get root_path

      expect(response.body).to include(I18n.t('navigation.detailed_report'))
      expect(response.body).to include('/reports/detailed')
    end

    it 'renders Stimulus dropdown controller on details elements' do
      get root_path

      expect(response.body).to include('data-controller="dropdown"')
    end
  end
end
