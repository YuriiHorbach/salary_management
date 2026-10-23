# frozen_string_literal: true

class HistoricalImportsController < ApplicationController
  before_action :authenticate_user!

  def new; end

  # Sends a header-only CSV template that users can fill in and upload back.
  def sample
    send_data HistoricalDataImporter::CsvTemplate.to_csv,
              filename: 'historical_import_sample.csv',
              type: 'text/csv; charset=utf-8',
              disposition: 'attachment'
  end

  def create
    file = params[:file]

    if file.blank?
      redirect_to new_historical_import_path, alert: t('flash.historical_imports.select_file')
      return
    end

    result = HistoricalDataImporter.new(file.read, type: params[:data_type]).call

    flash_for(result)
    redirect_to new_historical_import_path
  rescue CSV::MalformedCSVError => e
    redirect_to new_historical_import_path, alert: t('flash.historical_imports.invalid_csv', message: e.message)
  end

  private

  def flash_for(result)
    message = import_message(result)

    if result.errors.any?
      flash[:alert] = "#{message} #{result.errors.first(5).join('; ')}"
    else
      flash[:notice] = message
    end
  end

  def import_message(result)
    t('flash.historical_imports.completed', created: result.created, updated: result.updated, skipped: result.skipped)
  end
end
