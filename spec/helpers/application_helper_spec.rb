# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#flash_classes' do
    it 'returns complete class names for notices so Tailwind can scan them' do
      classes = helper.flash_classes('notice')

      expect(classes).to include('bg-blue-100', 'text-blue-700')
      expect(classes).not_to include('#{')
    end

    it 'returns complete class names for alerts' do
      classes = helper.flash_classes('alert')

      expect(classes).to include('bg-red-100', 'text-red-700')
      expect(classes).not_to include('#{')
    end

    it 'falls back to neutral styles for unknown flash types' do
      classes = helper.flash_classes('some_unknown_type')

      expect(classes).to include('bg-gray-100', 'text-gray-800')
    end

    it 'treats symbol keys like their string counterparts' do
      expect(helper.flash_classes(:notice)).to eq(helper.flash_classes('notice'))
    end
  end
end
