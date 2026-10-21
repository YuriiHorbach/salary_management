# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'current working month' do
    it 'normalizes a selected date to the first day of its month' do
      user = build(:user, current_working_month: Date.new(2025, 3, 15))

      user.valid?

      expect(user.current_working_month).to eq(Date.new(2025, 3, 1))
    end

    it 'allows the current working month to be blank' do
      user = build(:user, current_working_month: nil)

      expect(user).to be_valid
      expect(user.current_working_month).to be_nil
    end
  end
end
