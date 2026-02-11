# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
User.destroy_all
Employee.destroy_all

User.create!(email: 'admin@example.com', password: 'password')

Employee.find_or_create_by!(id_code: '1234567890') do |e|
  e.first_name = 'Ivan'
  e.last_name = 'Sirko'
  e.patronic_name = 'Ivanovych'
end
