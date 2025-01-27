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

  resources :departments, except: [:destroy]

  get '/home_pages/', to: 'home_pages#index'
end
