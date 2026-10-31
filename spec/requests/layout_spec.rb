# frozen_string_literal: true

require 'rails_helper'

# Guards the application shell: document title wiring, the responsive
# full-height flex page structure, and JIT-safe flash classes.
RSpec.describe 'Application layout', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }

  before { sign_in user }

  describe 'document title' do
    it 'falls back to the application name' do
      get root_path

      expect(response.body).to include("<title>#{I18n.t('navigation.app_name')}</title>")
    end

    it 'prefers the per-page title set via content_for' do
      get settings_root_path

      expected = "#{I18n.t('settings.dashboard.title')} · #{I18n.t('navigation.app_name')}"
      expect(response.body).to include("<title>#{expected}</title>")
    end
  end

  describe 'page shell' do
    it 'renders a full-height flex column body so content can stretch' do
      get root_path

      expect(response.body).to match(/<body[^>]*class="[^"]*min-h-screen[^"]*flex-col/)
    end

    it 'stretches the main content area' do
      get root_path

      expect(response.body).to match(/<main[^>]*class="[^"]*\bflex-1\b/)
    end

    it 'keeps the flash container target for Turbo Streams' do
      get root_path

      expect(response.body).to include('id="flash"')
    end
  end

  describe 'flash messages' do
    it 'renders notices with complete Tailwind class names' do
      patch current_working_month_path, params: { current_working_month: '2025-04' }
      follow_redirect!

      alert = Nokogiri::HTML(response.body).at_css('[role="alert"]')
      expect(alert).not_to be_nil
      expect(alert['class']).to include('bg-blue-100', 'text-blue-700')
    end

    it 'renders alerts with complete Tailwind class names' do
      patch current_working_month_path, params: { current_working_month: 'not-a-month' }
      follow_redirect!

      alert = Nokogiri::HTML(response.body).at_css('[role="alert"]')
      expect(alert).not_to be_nil
      expect(alert['class']).to include('bg-red-100', 'text-red-700')
    end
  end
end
