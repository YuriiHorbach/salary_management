# frozen_string_literal: true

class AccountBook < ApplicationRecord
  belongs_to :employee

  validates :book_name, presence: true

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
