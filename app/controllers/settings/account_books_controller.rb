# frozen_string_literal: true

class Settings::AccountBooksController < Settings::BaseController
  before_action :set_account_book, only: %i[edit update destroy]

  def index
    @account_books = AccountBook.includes(:employee).order(:code)
  end

  def new
    @account_book = AccountBook.new
  end

  def edit; end

  def create
    @account_book = AccountBook.new(account_book_params)

    if @account_book.save
      redirect_to settings_account_books_path, notice: t('flash.settings.account_books.created')
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @account_book.update(account_book_params)
      redirect_to settings_account_books_path, notice: t('flash.settings.account_books.updated')
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @account_book.destroy
    redirect_to settings_account_books_path, notice: t('flash.settings.account_books.deleted')
  end

  private

  def set_account_book
    @account_book = AccountBook.find(params[:id])
  end

  def account_book_params
    params.require(:account_book).permit(:code)
  end
end
