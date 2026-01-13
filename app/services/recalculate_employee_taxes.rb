class RecalculateEmployeeTaxes
  RECENT_PERIOD = 24.hours

  def self.call(employee)
    new(employee).call
  end

  def initialize(employee)
    @employee = employee
  end

  def call
    recent_salaries.find_each do |salary|
      enqueue_recalculation(salary)
    end
  end

  private

  def recent_salaries
    @employee.salaries.where('created_at >= ?', RECENT_PERIOD.ago)
  end

  def enqueue_recalculation(salary)
    TaxCalculationJob.perform_later(salary.id)
  end
end
