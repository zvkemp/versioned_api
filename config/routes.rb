Rails.application.routes.draw do
  namespace :api, path: '/api/:version' do
    resources :users
  end
end
