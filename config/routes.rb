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
    resources :positions, only: %i[create], controller: 'department_positions'

    resources :employees, only: [] do
      resource :positions, only: %i[edit update destroy], controller: 'department_employee_positions'
      delete 'remove', on: :member, to: 'department_employees#destroy'
    end
  end

  resources :employees do
    resources :sick_days
    resources :vacations
  end

  resources :sick_day_entries, only: %i[new create]
  resources :vacation_entries, only: %i[new create]

  resources :historical_imports, only: %i[new create] do
    get :sample, on: :collection
  end

  resources :reports, only: [:index] do
    get :summary, on: :collection
    get :detailed, on: :collection
  end

  get '/home_pages/', to: 'home_pages#index'
  patch '/home_pages/current_working_month',
        to: 'home_pages#update_current_working_month',
        as: :current_working_month

  namespace :settings do
    root to: 'dashboard#index'
    resources :territory_signs, except: [:show]
    resources :account_books, except: [:show]
    resource :tax_settings, only: %i[edit update]
    resource :application_setting, only: %i[edit update]
  end
end
