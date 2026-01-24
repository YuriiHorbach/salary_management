# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users
  # root 'users#index'
  root 'home_pages#index'
  resources :employees do
    resources :salaries
  end

  resources :users, only: %i[index destroy]

  resources :department_employees, only: %i[new create]

  resources :departments do
    resources :employees, only: [] do
      delete 'remove', on: :member, to: 'department_employees#destroy'
    end
  end

  resources :employees do
    resources :sick_days
  end

  resources :reports, only: [:index]

  get '/home_pages/', to: 'home_pages#index'
end
