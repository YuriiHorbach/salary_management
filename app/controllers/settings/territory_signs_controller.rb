# frozen_string_literal: true

class Settings::TerritorySignsController < Settings::BaseController
  before_action :set_territory_sign, only: %i[edit update destroy]

  def index
    @territory_signs = TerritorySign.order(:name)
  end

  def new
    @territory_sign = TerritorySign.new
  end

  def edit; end

  def create
    @territory_sign = TerritorySign.new(territory_sign_params)

    if @territory_sign.save
      redirect_to settings_territory_signs_path, notice: 'Теріторіальну ознаку додано.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @territory_sign.update(territory_sign_params)
      redirect_to settings_territory_signs_path, notice: 'Теріторіальну оновлено.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @territory_sign.destroy
    redirect_to settings_territory_signs_path, notice: 'Теріторіальну ознаку видалено.'
  end

  private

  def set_territory_sign
    @territory_sign = TerritorySign.find(params[:id])
  end

  def territory_sign_params
    params.require(:territory_sign).permit(:name)
  end
end
