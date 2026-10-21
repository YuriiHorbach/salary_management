# frozen_string_literal: true

class HistoricalImportsController < ApplicationController
  before_action :authenticate_user!

  def new; end

  def create
    file = params[:file]

    if file.blank?
      redirect_to new_historical_import_path, alert: 'Оберіть CSV-файл для імпорту.'
      return
    end

    result = HistoricalDataImporter.new(file.read, type: params[:data_type]).call

    flash_for(result)
    redirect_to new_historical_import_path
  rescue CSV::MalformedCSVError => e
    redirect_to new_historical_import_path, alert: "Некоректний CSV-файл: #{e.message}"
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
    "Імпорт завершено: додано #{result.created}, оновлено #{result.updated}, " \
      "пропущено #{result.skipped}."
  end
end
