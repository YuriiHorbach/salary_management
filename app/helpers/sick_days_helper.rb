# frozen_string_literal: true

module SickDaysHelper
  def summary_amount_for(summaries, period, type)
    summary = summaries&.[](period)
    return nil unless summary && summary[type]

    number_to_currency(summary[type])
  end
end
