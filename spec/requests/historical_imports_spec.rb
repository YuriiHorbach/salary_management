# frozen_string_literal: true

require 'rails_helper'
require 'tempfile'

RSpec.describe 'Historical imports', type: :request do
  let(:user) { create(:user) }
  let!(:employee) { create(:employee, id_code: '1234567890') }

  let(:csv) do
    <<~CSV
      id_code,period,amount,income_tax,military_tax,net_amount
      1234567890,2020-03,1000,111,22,867
    CSV
  end

  def upload(csv)
    file = Tempfile.new(['historical', '.csv'])
    file.write(csv)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, 'text/csv', original_filename: 'old-data.csv')
  end

  before { ActiveJob::Base.queue_adapter = :test }

  describe 'GET /historical_imports/new' do
    it 'requires authentication' do
      get new_historical_import_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'renders the import form' do
      sign_in user

      get new_historical_import_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Імпорт старих даних')
      expect(response.body).to include('file')
    end

    it 'offers a downloadable CSV template' do
      sign_in user

      get new_historical_import_path

      expect(response.body).to include('Завантажити зразок CSV')
      expect(response.body).to include(sample_historical_imports_path)
    end

    it 'explains every column of the sample CSV' do
      sign_in user

      get new_historical_import_path

      rows = response.parsed_body.css('#csv-columns tbody tr')
      documented = rows.filter_map { |row| row.at_css('code')&.text }

      expect(documented).to match_array(HistoricalDataImporter::CsvTemplate.headers)
      expect(rows.map(&:text).join.downcase).to include('тип запису', 'місяць', 'військовий збір')
    end
  end

  describe 'GET /historical_imports/sample' do
    it 'requires authentication' do
      get sample_historical_imports_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it 'downloads a header-only CSV file' do
      sign_in user

      get sample_historical_imports_path

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/csv')
      expect(response.headers['Content-Disposition']).to include('attachment')
      expect(response.body).to include('type,id_code,identifier,period')

      rows = CSV.parse(response.body, headers: true)
      expect(rows).to be_empty
      expect(rows.headers).to include('amount', 'pfu_amount', 'vacation_amount', 'department')
    end
  end

  describe 'POST /historical_imports' do
    before { sign_in user }

    it 'imports the CSV and redirects with a success message' do
      post historical_imports_path, params: { file: upload(csv), data_type: 'salary' }

      expect(response).to redirect_to(new_historical_import_path)
      follow_redirect!

      expect(response.body).to include('Імпорт завершено')
      expect(employee.salaries.count).to eq(1)
      expect(employee.salaries.first.income_tax_cents).to eq(11_100)
    end

    it 'rebuilds the period income aggregate used by reports' do
      post historical_imports_path, params: { file: upload(csv), data_type: 'salary' }

      aggregate = EmployeePeriodIncome.find_by(
        employee: employee, period: Date.new(2020, 3, 1), income_type: 'salary'
      )

      expect(aggregate).to be_present
      expect(aggregate.gross_cents).to eq(100_000)
    end

    it 'does not enqueue tax recalculation while importing' do
      expect do
        post historical_imports_path, params: { file: upload(csv), data_type: 'salary' }
      end.not_to have_enqueued_job(TaxCalculationJob)
    end

    it 'redirects with an alert when no file is selected' do
      post historical_imports_path, params: { data_type: 'salary' }

      expect(response).to redirect_to(new_historical_import_path)
      follow_redirect!

      expect(response.body).to include('Оберіть CSV-файл')
    end

    it 'reports rows that could not be matched to an employee' do
      bad_csv = <<~CSV
        id_code,period,amount
        9999999999,2020-03,1000
      CSV

      post historical_imports_path, params: { file: upload(bad_csv), data_type: 'salary' }
      follow_redirect!

      expect(response.body).to include('пропущено')
      expect(response.body).to include('9999999999')
      expect(Salary.count).to eq(0)
    end
  end
end
