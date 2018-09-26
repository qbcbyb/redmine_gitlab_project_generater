# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
RedmineApp::Application.routes.draw do
  match 'project_generater', :to => 'project_generater#index', :via => [:get, :post]
  post 'project_generater/source', :to => 'project_generater#getprojects'
  get 'project_generater/oauth', :to => 'project_generater#gitlab_oauth'
  get 'project_generater/oauth_callback', :to => 'project_generater#gitlab_oauth_callback'
end
