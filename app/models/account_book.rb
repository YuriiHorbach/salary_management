# frozen_string_literal: true

# Catalog entry for an account book code.
#
# Codes are unique and shared: several employees may reference the same book.
# The denormalized +employees.identifier+ column is kept in sync when a book is
# assigned, renamed or deleted.
class AccountBook < ApplicationRecord
  has_many :employees, dependent: :nullify

  before_validation :normalize_code
  before_destroy :clear_employee_identifiers, prepend: true
  after_update :sync_employee_identifiers, if: :saved_change_to_code?

  validates :code, presence: true,
                   uniqueness: { case_sensitive: false },
                   format: { with: /\A[А-ЯЄІЇҐA-Z]\d+\z/, message: :code_format }

  # Unique book codes available to assign to employees, ordered for selects.
  #
  # @return [Array<String>]
  def self.available_codes
    order(:code).distinct.pluck(:code)
  end

  private

  def normalize_code
    self.code = code.to_s.strip.upcase if code.present?
  end

  def sync_employee_identifiers
    employees.update_all(identifier: code)
  end

  def clear_employee_identifiers
    employees.update_all(identifier: nil)
  end
end
