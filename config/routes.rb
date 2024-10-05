Rails.application.routes.draw do
  devise_for :users
  # root 'users#index'
  root 'home_pages#index'

  resources :employees

  resources :users, only: %i[index destroy]

  resources :departments do
    resources :salaries, only: %i[index edit update create]
  end

  get '/home_pages/', to: 'home_pages#index'
end
