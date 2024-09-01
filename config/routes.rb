Rails.application.routes.draw do
  devise_for :users
  root 'users#index'

  resources :employees

  namespace :admin do
    resources :admins, only: %i[index]
    resources :users, only: %i[index destroy]
  end
end
