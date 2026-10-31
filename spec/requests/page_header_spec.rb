# frozen_string_literal: true

require 'rails_helper'

# The shared page header partial must keep the title and action links in a
# wrapping flex row (no fixed margins) on every page that adopts it: stacked
# on narrow screens, inline from `sm` up, and free to wrap instead of using
# pixel offsets like `ml-4`.
RSpec.describe 'Shared page header', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let(:employee) { create(:employee) }

  before { sign_in user }

  def page_header_for(response_body)
    Nokogiri::HTML(response_body).at_css('header[data-page-header]')
  end

  def expect_responsive_header(header, title)
    expect(header).not_to be_nil
    # Stacked on mobile, single row from the `sm` breakpoint up.
    expect(header['class']).to include('flex-col', 'sm:flex-row', 'justify-between')
    expect(header.at_css('h1').text.strip).to include(title)
    expect(header.css('a').size).to eq(2)
    expect_actions_may_wrap(header)
  end

  def expect_actions_may_wrap(header)
    # Action links may wrap; no fixed pixel margins.
    expect(header.to_html).to include('flex-wrap')
    expect(header.to_html).not_to include('ml-4')
  end

  it 'wraps the sick days index title and actions' do
    get employee_sick_days_path(employee)

    expect_responsive_header(
      page_header_for(response.body),
      I18n.t('sick_days.index.title', name: "#{employee.last_name} #{employee.first_name}")
    )
  end

  it 'wraps the vacations index title and actions' do
    get employee_vacations_path(employee)

    expect_responsive_header(
      page_header_for(response.body),
      I18n.t('vacations.index.title', name: "#{employee.last_name} #{employee.first_name}")
    )
  end
end
