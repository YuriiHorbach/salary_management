# frozen_string_literal: true

# Represents an authenticated application user.
#
# Each user can persist a +current_working_month+ that may differ from the
# calendar month. Controllers and forms use it as the default payroll period
# for salary, vacation, and sick-day entries.
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :rememberable, :validatable

  before_validation :normalize_current_working_month

  private

  def normalize_current_working_month
    self.current_working_month = current_working_month.beginning_of_month if current_working_month.present?
  end
end
