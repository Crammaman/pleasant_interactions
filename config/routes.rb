Rails.application.routes.draw do
  root "home#index"

  get    "login",  to: "sessions#new"
  post   "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  resources :users, only: %i[new create edit update]

  resources :profiles, only: [] do
    # Jumps to the profile's current queue (creating one if needed).
    get :queue, on: :member, to: "queues#current"
  end

  resources :queues, only: %i[show] do
    # Persists a drag-and-drop reorder of the queue's interactions.
    patch :reorder, on: :member

    resources :interactions, only: %i[new create]
  end

  resources :interactions, only: %i[edit update] do
    member do
      patch :start
      patch :finish
      patch :remove # sets state to deleted (soft delete)
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
