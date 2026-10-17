# frozen_string_literal: true

class AccountBook < ApplicationRecord
  belongs_to :employee, optional: true

  validates :code, presence: true, uniqueness: true,
                   format: { with: /\A[А-ЯЄІЇҐA-Z]\d+\z/, message: 'має бути у форматі Б11 (літера бригади та номери)' }

  def book_code
    return nil if book_number.nil? || page_number.nil?

    "#{book_number}-#{page_number}"
  end

  def territory_page_code
    return nil unless employee&.territory_sign
    return nil unless book_number && page_number

    first_letter = employee.territory_sign.name.to_s.strip[0]&.downcase
    return nil unless first_letter

    format('%s%d%d', first_letter, book_number, page_number)
  end
end
