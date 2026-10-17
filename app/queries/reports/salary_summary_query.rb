# frozen_string_literal: true

module Reports
  # Aggregates salary, vacation and sick-day data grouped by brigade (territory)
  # and account book, producing a pivot-table-ready structure for the Summary Report.
  class SalarySummaryQuery
    # All monetary columns in UAH (already divided by 100 from cents).
    COLUMN_KEYS = %i[
      salary_gross_vacation
      salary_income_tax
      salary_military_tax
      salary_net
      salary_net_income_tax
      salary_net_military_tax
      vacation_amount
      vacation_income_tax
      vacation_military_tax
      sick_total
      sick_pdfo
      sick_military
      total_income
      total_tax
      total_military
    ].freeze

    COLUMN_LABELS = {
      salary_gross_vacation: 'зарплата зп+відп',
      salary_income_tax: 'зп_нараховано податку',
      salary_military_tax: 'зп_військовий збір',
      salary_net: 'чиста_зп',
      salary_net_income_tax: 'чиста_зп_податок',
      salary_net_military_tax: 'чиста_зп_вз',
      vacation_amount: 'відпускні',
      vacation_income_tax: 'відп_нараховано податку',
      vacation_military_tax: 'відп_військовий збір',
      sick_total: 'лікарняні',
      sick_pdfo: 'лік_нараховано податку',
      sick_military: 'лік_військовий збір',
      total_income: 'Загальний дохід (зп+вп+лік)',
      total_tax: 'Загальний податок (зп+вп+лік)',
      total_military: 'Загальний вз (зп+вп+лік)'
    }.freeze

    def initialize(params = {})
      @params = params || {}
    end

    def call
      brigades, grand_total = build_data
      {
        brigades: brigades,
        grand_total: grand_total
      }
    end

    private

    def build_data
      employees = Employee.includes(:account_book, :territory_sign).all

      salary_agg = salary_aggregates
      vacation_agg = vacation_aggregates
      sick_agg = sick_day_aggregates

      grouped = employees.group_by { |e| [e.territory_sign&.name.to_s, e.account_book&.code.to_s] }

      brigades = {}
      grand_total = zero_hash

      grouped.each do |(brigade, book_code), emps|
        brigades[brigade] ||= { books: {}, total: zero_hash }
        brigades[brigade][:books][book_code] ||= zero_hash

        emps.each do |emp|
          s = salary_agg[emp.id] || salary_zero
          v = vacation_agg[emp.id] || vacation_zero
          sk = sick_agg[emp.id] || sick_zero

          row = compute_row(s, v, sk)

          brigades[brigade][:books][book_code] = add_hashes(brigades[brigade][:books][book_code], row)
          brigades[brigade][:total] = add_hashes(brigades[brigade][:total], row)
          grand_total = add_hashes(grand_total, row)
        end
      end

      [brigades, grand_total]
    end

    def salary_aggregates
      Salary
        .group(:employee_id)
        .pluck(
          :employee_id,
          Arel.sql('COALESCE(SUM(amount_cents), 0)'),
          Arel.sql('COALESCE(SUM(income_tax_cents), 0)'),
          Arel.sql('COALESCE(SUM(military_tax_cents), 0)'),
          Arel.sql('COALESCE(SUM(net_amount_cents), 0)')
        )
        .index_by(&:first)
        .transform_values do |v|
          {
            gross: v[1] / 100.0,
            income_tax: v[2] / 100.0,
            military_tax: v[3] / 100.0,
            net: v[4] / 100.0
          }
        end
    end

    def vacation_aggregates
      Vacation
        .group(:employee_id)
        .pluck(
          :employee_id,
          Arel.sql('COALESCE(SUM(vacation_amount_cents), 0)'),
          Arel.sql('COALESCE(SUM(income_tax_cents), 0)'),
          Arel.sql('COALESCE(SUM(military_tax_cents), 0)')
        )
        .index_by(&:first)
        .transform_values do |v|
          {
            amount: v[1] / 100.0,
            income_tax: v[2] / 100.0,
            military_tax: v[3] / 100.0
          }
        end
    end

    def sick_day_aggregates
      SickDay
        .group(:employee_id)
        .pluck(
          :employee_id,
          Arel.sql('COALESCE(SUM(pfu_amount_cents + enterprise_amount_cents), 0)'),
          Arel.sql('COALESCE(SUM((pfu_amount_cents + enterprise_amount_cents) * 0.18), 0)'),
          Arel.sql('COALESCE(SUM((pfu_amount_cents + enterprise_amount_cents) * 0.05), 0)')
        )
        .index_by(&:first)
        .transform_values do |v|
          {
            total: v[1] / 100.0,
            pdfo: v[2] / 100.0,
            military: v[3] / 100.0
          }
        end
    end

    def compute_row(salary, vacation, sick)
      salary_gross_vacation = salary[:gross] + vacation[:amount]

      {
        salary_gross_vacation: salary_gross_vacation,
        salary_income_tax: salary[:income_tax],
        salary_military_tax: salary[:military_tax],
        salary_net: salary[:net],
        salary_net_income_tax: salary[:income_tax],
        salary_net_military_tax: salary[:military_tax],
        vacation_amount: vacation[:amount],
        vacation_income_tax: vacation[:income_tax],
        vacation_military_tax: vacation[:military_tax],
        sick_total: sick[:total],
        sick_pdfo: sick[:pdfo],
        sick_military: sick[:military],
        total_income: salary_gross_vacation + sick[:total],
        total_tax: salary[:income_tax] + vacation[:income_tax] + sick[:pdfo],
        total_military: salary[:military_tax] + vacation[:military_tax] + sick[:military]
      }
    end

    def salary_zero
      { gross: 0.0, income_tax: 0.0, military_tax: 0.0, net: 0.0 }
    end

    def vacation_zero
      { amount: 0.0, income_tax: 0.0, military_tax: 0.0 }
    end

    def sick_zero
      { total: 0.0, pdfo: 0.0, military: 0.0 }
    end

    def zero_hash
      COLUMN_KEYS.index_with { 0.0 }
    end

    def add_hashes(h1, h2)
      h1.merge(h2) { |_, v1, v2| v1 + v2 }
    end
  end
end
