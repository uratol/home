private

def uniRoutes
  get 'entities/classes'
  resources :entities
  get '/entities/:id/destroy' => 'entities#destroy'
  get '/entities/insert/:parent' => 'entities#insert'

  post '/main/click'
  post '/main/change'
  post '/main/touchstart'
  post '/main/touchend'
  get '/main/refresh'
  get '/main/reseed'
  
  post '/admin/reboot'
  
  get '/show/:name' => 'main#show'
  get '/show/:id' => 'main#show'
  post '/show/:id' => 'main#show'
  
  post '/main/design_apply'

  scope :butler do
    post '/command' => "butler#command"
    get '/command' => "butler#command"
  end
  
  get '/driver/read' => "http_driver#read"
  get '/driver/write' => "http_driver#write"

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'main#show'

  scope :api do
    get "/tts/:lang/" => "speech#speak"
    get "/command/:command/" => "speech#speak"
  end

  devise_for :users
  resources :users
  resources :drivers
end

public

Home::Engine.routes.draw do
  uniRoutes
end

Rails.application.routes.draw do
  uniRoutes
end

