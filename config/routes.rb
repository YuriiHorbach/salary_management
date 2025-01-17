Rails.application.routes.draw do
  devise_for :users
  # root 'users#index'
  root 'home_pages#index'
  resources :employees do
    resources :salaries
  end

  resources :users, only: %i[index destroy]
  resources :department_employees, only: %i[new create]

  resources :departments, except:  [:destroy]

  get '/home_pages/', to: 'home_pages#index'
end
