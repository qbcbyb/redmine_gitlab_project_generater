require 'redmine'

Redmine::Plugin.register :redmine_gitlab_project_generater do
  name 'Redmine Gitlab Project Generater plugin'
  author 'Hydrant'
  description 'This is a gitlab project generater plugin for Redmine'
  version '0.0.2'
  url 'https://github.com/qbcbyb/redmine_gitlab_project_generater'
  author_url 'https://github.com/qbcbyb'
  requires_redmine :version_or_higher => '2.3.0'

  settings :default => {
      :git_remote_url => '',
      :client_id => "",
      :client_secret => "",
      :gitlab_api_v4 => false,
  }, :partial => 'settings/gitlab_project_generater_settings'

  Redmine::MenuManager.map :top_menu do |menu|
    menu.push :gitlab_project_generater, {:controller => 'project_generater', :action => 'index'}, :caption => :gitlab_project_generater
  end
end
