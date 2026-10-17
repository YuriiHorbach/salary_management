# frozen_string_literal: true

class AccountBook < ApplicationRecord
  belongs_to :employee, optional: true

  validates :code, presence: true,
                   format: { with: /\A[А-ЯЄІЇҐA-Z]\d+\z/, message: 'має бути у форматі Б11 (літера бригади та номери)' }

  after_save :refresh_employee_identifier
  after_destroy :clear_employee_identifier

  private

  # Keep the denormalized employees.identifier column in sync with the book code.
  def refresh_employee_identifier
    return unless employee

    employee.update_column(:identifier, code)
  end

  def clear_employee_identifier
    return unless employee

    employee.update_column(:identifier, nil)
  end
end
