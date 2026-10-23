# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Current working month', type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe 'GET /' do
    it 'reminds the user to choose a current working month when none is set' do
      get root_path

      page = Nokogiri::HTML(response.body)
      input = page.at_css('input[name="current_working_month"]')

      expect(response).to have_http_status(:ok)
      expect(page.text).to include(I18n.t('home_pages.index.choose_month'))
      expect(input['value']).to eq(Date.current.strftime('%Y-%m'))
    end

    it 'shows the persisted current working month' do
      user.update!(current_working_month: Date.new(2025, 3, 1))

      get root_path

      page = Nokogiri::HTML(response.body)
      input = page.at_css('input[name="current_working_month"]')

      expect(input['value']).to eq('2025-03')
      expect(page.text).to include(I18n.t('home_pages.index.current_month', month: '03.2025'))
      expect(page.text).to include('03.2025')
    end
  end

  describe 'PATCH /home_pages/current_working_month' do
    it 'persists the selected month for the current user' do
      patch current_working_month_path, params: { current_working_month: '2025-04' }

      expect(response).to redirect_to(root_path)
      expect(user.reload.current_working_month).to eq(Date.new(2025, 4, 1))
      expect(flash[:notice]).to eq(I18n.t('home_pages.flash.month_saved', month: '04.2025'))
    end

    it 'does not change another user setting' do
      other_user = create(:user, current_working_month: Date.new(2025, 1, 1))

      patch current_working_month_path, params: { current_working_month: '2025-04' }

      expect(other_user.reload.current_working_month).to eq(Date.new(2025, 1, 1))
    end

    it 'rejects an invalid month' do
      patch current_working_month_path, params: { current_working_month: 'not-a-month' }

      expect(response).to redirect_to(root_path)
      expect(user.reload.current_working_month).to be_nil
      expect(flash[:alert]).to eq(I18n.t('home_pages.flash.invalid_month'))
    end
  end
end
