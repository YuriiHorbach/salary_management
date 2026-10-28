# frozen_string_literal: true

module Reports
  # Updates an employee's page number from the inline selector in the detailed
  # report. The selected number is stored together with the book code from the
  # employee profile, for example +1+ and +Б111+ become +1-Б111+.
  class PageNumbersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_employee

    # Combines the selected page number with the employee's current book code
    # and replaces the corresponding report cell.
    #
    # @return [void]
    def update
      number = normalized_number
      book_code = @employee.account_book&.code

      return head :unprocessable_content unless number && book_code.present?

      @employee.update!(page_number: "#{number}-#{book_code}")

      respond_to do |format|
        format.turbo_stream { render_page_number_cell }
        format.html { redirect_to return_path, notice: t('flash.employees.updated') }
      end
    end

    private

    def set_employee
      @employee = Employee.find(params.require(:employee_page_number)[:employee_id])
    end

    def normalized_number
      raw = params.dig(:employee_page_number, :number).to_s
      return unless raw.match?(/\A\d+\z/)

      number = raw.to_i
      number.to_s if number.positive?
    end

    def return_path
      path = params.dig(:employee_page_number, :return_to).to_s
      path.start_with?('/') && !path.start_with?('//') ? path : detailed_reports_path
    end

    def render_page_number_cell
      row = {
        employee_id: @employee.id,
        book_code: @employee.account_book&.code,
        page_number: @employee.page_number
      }

      render turbo_stream: turbo_stream.replace(
        helpers.detailed_report_page_number_frame_id(row),
        partial: 'reports/page_numbers/cell',
        locals: { row: row }
      )
    end
  end
end
