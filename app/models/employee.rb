# frozen_string_literal: true

class Employee < ApplicationRecord
  has_many :department_employees
  has_many :departments, through: :department_employees
  has_many :positions, through: :department_employees
  has_many :salaries, dependent: :destroy

  validates :id_code, presence: true, length: { minimum: 10, maximum: 10 }, uniqueness: true
  validates :first_name, presence: true
  validates :patronic_name, presence: true
  validates :last_name, presence: true


  after_save :recalculate_taxes_if_needed

  def self.ransackable_attributes(_auth_object = nil)
    %w[created_at first_name id id_code id_value last_name patronic_name updated_at children_count disability_group
       chaes contract territory_info]
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[department_employees departments positions salaries]
  end

  def total_salary
    salaries.sum(:amount)
  end

  private

  # def recalculate_recent_salary
  #   latest_salary = salaries.reload.last
  #   if latest_salary && latest_salary.created_at > 10.hours.ago
  #     latest_salary.employee = self
  #     latest_salary.save
  #   end
  # end

  # def recalculate_recent_salary
  #   latest_salary = salaries.order(created_at: :desc).first
  #   return unless latest_salary
  #   return unless latest_salary.created_at > 10.hours.ago
  
  #   TaxCalculationJob.perform_later(latest_salary.id)
  # end

  def recalculate_taxes_if_needed
    return unless tax_affecting_attributes_changed?
    
    RecalculateEmployeeTaxes.call(self)
  end

  def tax_affecting_attributes_changed?
    saved_change_to_children_count? ||
      saved_change_to_disability_group? ||
      saved_change_to_chaes? ||
      saved_change_to_contract?
  end
end
