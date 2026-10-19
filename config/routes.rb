# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users
  # root 'users#index'
  root 'home_pages#index'
  resources :employees do
    resources :salaries
  end

  resources :users, only: %i[index destroy]

  resources :department_employees, only: %i[new create destroy]

  resources :departments do
    resources :employees, only: [] do
      delete 'remove', on: :member, to: 'department_employees#destroy'
    end
  end

  resources :employees do
    resources :sick_days
    resources :vacations
  end

  resources :sick_day_entries, only: %i[new create]
  resources :vacation_entries, only: %i[new create]

  resources :reports, only: [:index] do
    get :summary, on: :collection
    get :detailed, on: :collection
  end

  get '/home_pages/', to: 'home_pages#index'

  namespace :settings do
    root to: 'dashboard#index'
    resources :territory_signs, except: [:show]
    resources :account_books, except: [:show]
    resource :tax_settings, only: %i[edit update]
  end
end
