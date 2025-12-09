# frozen_string_literal: true

module ReportsHelper
  START_YEAR = 2000

  def year_options
    (START_YEAR..Time.now.year).to_a.reverse
  end

  def month_options
    (1..12).map { |m| [Date::MONTHNAMES[m], m] }
  end
end
