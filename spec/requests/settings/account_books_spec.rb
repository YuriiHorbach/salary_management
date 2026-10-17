# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AccountBooks settings', type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:employee) { create(:employee) }

  before do
    sign_in user
    ActiveJob::Base.queue_adapter = :test
  end

  describe 'GET /settings/account_books' do
    it 'returns successful response' do
      get settings_account_books_path
      expect(response).to have_http_status(:ok)
    end

    it 'displays account books list' do
      create(:account_book, employee: employee, book_name: 'Книга А', book_number: 1, page_number: 5)
      create(:account_book, employee: employee, book_name: 'Книга Б', book_number: 2, page_number: 10)

      get settings_account_books_path
      expect(response.body).to include('Книга А')
      expect(response.body).to include('Книга Б')
    end
  end

  describe 'GET /settings/account_books/new' do
    it 'returns successful response' do
      get new_settings_account_book_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /settings/account_books' do
    context 'with valid params' do
      it 'creates a new account book' do
        expect {
          post settings_account_books_path, params: {
            account_book: {
              employee_id: employee.id,
              book_name: 'Книга В',
              book_number: 3,
              page_number: 1
            }
          }
        }.to change(AccountBook, :count).by(1)

        expect(response).to redirect_to(settings_account_books_path)
        follow_redirect!
        expect(response.body).to include('Книга В')
      end
    end

    context 'with invalid params' do
      it 'does not create without book_name' do
        expect {
          post settings_account_books_path, params: {
            account_book: { employee_id: employee.id, book_name: '' }
          }
        }.not_to change(AccountBook, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not create without employee' do
        expect {
          post settings_account_books_path, params: {
            account_book: { book_name: 'Книга', book_number: 1, page_number: 1 }
          }
        }.not_to change(AccountBook, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET /settings/account_books/:id/edit' do
    it 'returns successful response' do
      book = create(:account_book, employee: employee, book_name: 'Редагується')
      get edit_settings_account_book_path(book)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Редагується')
    end
  end

  describe 'PATCH /settings/account_books/:id' do
    context 'with valid params' do
      it 'updates the account book' do
        book = create(:account_book, employee: employee, book_name: 'Старе', book_number: 1, page_number: 1)
        patch settings_account_book_path(book), params: {
          account_book: { book_name: 'Нове', book_number: 2, page_number: 3 }
        }

        expect(response).to redirect_to(settings_account_books_path)
        expect(book.reload.book_name).to eq('Нове')
        expect(book.reload.book_number).to eq(2)
        expect(book.reload.page_number).to eq(3)
      end
    end

    context 'with invalid params' do
      it 'does not update' do
        book = create(:account_book, employee: employee, book_name: 'Оригінал')
        patch settings_account_book_path(book), params: { account_book: { book_name: '' } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(book.reload.book_name).to eq('Оригінал')
      end
    end
  end

  describe 'DELETE /settings/account_books/:id' do
    it 'deletes the account book' do
      book = create(:account_book, employee: employee)
      expect {
        delete settings_account_book_path(book)
      }.to change(AccountBook, :count).by(-1)

      expect(response).to redirect_to(settings_account_books_path)
    end
  end
end
