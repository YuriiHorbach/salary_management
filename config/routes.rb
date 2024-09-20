Rails.application.routes.draw do
  devise_for :users
  # root 'users#index'
  root 'home_pages#index'

  resources :employees

  resources :users, only: %i[index destroy]

  resources :departments

  # get '/home_pages/', to: 'home_pages#index'
end
