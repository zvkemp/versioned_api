TrailTest::Application.routes.draw do
  namespace :api do
    # resources :users

    match ':version', action: :perform, controller: :base
    match ':version/*path', action: :perform, controller: :base
  end
end
