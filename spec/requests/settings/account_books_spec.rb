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
      create(:account_book, employee: employee, code: 'А11')
      create(:account_book, employee: employee, code: 'Б22')

      get settings_account_books_path
      expect(response.body).to include('А11')
      expect(response.body).to include('Б22')
    end

    it 'renders the delete link as a Turbo DELETE request' do
      book = create(:account_book, employee: employee, code: 'Б77')
      get settings_account_books_path

      link = Nokogiri::HTML(response.body).at_css("a[href='#{settings_account_book_path(book)}']")
      expect(link['data-turbo-method']).to eq('delete')
      expect(link['data-turbo-confirm']).to be_present
      expect(link['data-method']).to be_nil
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
          post settings_account_books_path, params: { account_book: { code: 'В31' } }
        }.to change(AccountBook, :count).by(1)

        expect(response).to redirect_to(settings_account_books_path)
        follow_redirect!
        expect(response.body).to include('В31')
      end
    end

    context 'with invalid params' do
      it 'does not create without code' do
        expect {
          post settings_account_books_path, params: { account_book: { code: '' } }
        }.not_to change(AccountBook, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not create with an invalid code format' do
        expect {
          post settings_account_books_path, params: { account_book: { code: 'invalid' } }
        }.not_to change(AccountBook, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not create a duplicate code' do
        create(:account_book, code: 'В31')

        expect {
          post settings_account_books_path, params: { account_book: { code: 'В31' } }
        }.not_to change(AccountBook, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET /settings/account_books/:id/edit' do
    it 'returns successful response' do
      book = create(:account_book, employee: employee, code: 'Г44')
      get edit_settings_account_book_path(book)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Г44')
    end
  end

  describe 'PATCH /settings/account_books/:id' do
    context 'with valid params' do
      it 'updates the account book' do
        book = create(:account_book, employee: employee, code: 'Д55')
        patch settings_account_book_path(book), params: { account_book: { code: 'Е66' } }

        expect(response).to redirect_to(settings_account_books_path)
        expect(book.reload.code).to eq('Е66')
      end
    end

    context 'with invalid params' do
      it 'does not update' do
        book = create(:account_book, employee: employee, code: 'Ж77')
        patch settings_account_book_path(book), params: { account_book: { code: '' } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(book.reload.code).to eq('Ж77')
      end
    end
  end

  describe 'DELETE /settings/account_books/:id' do
    it 'deletes the account book and unassigns it from employees' do
      book = create(:account_book, employee: employee, code: 'К12')
      expect(employee.reload.identifier).to eq('К12')

      expect {
        delete settings_account_book_path(book)
      }.to change(AccountBook, :count).by(-1)

      expect(response).to redirect_to(settings_account_books_path)
      expect(employee.reload.account_book).to be_nil
      expect(employee.identifier).to be_nil
    end
  end
end
