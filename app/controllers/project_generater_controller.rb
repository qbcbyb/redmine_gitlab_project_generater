require 'json'
require 'gitlab'

class ProjectGeneraterController < ApplicationController

  (skip_before_filter :verify_authenticity_token, :check_if_login_required) if ENV['RAILS_ENV'] == 'production'

  def index
    gitlab_token_value = User.current.try('gitlab_token_value')

    remote_url = Setting.plugin_redmine_gitlab_hook['git_remote_url']
    gitlab_api_v4 = Setting.plugin_redmine_gitlab_hook['gitlab_api_v4']

    gitlab_api_version = gitlab_api_v4 ? 4 : 3

    if !gitlab_token_value || gitlab_token_value.empty?
      flash.now[:error] = 'No Token'
      return
    end

    g = Gitlab.client(endpoint: URI.join(remote_url, "/api/v#{gitlab_api_version}").to_s, private_token: gitlab_token_value)
    if request.post?
      import_urls = params[:import_url]
      access_token = session[:gitlab_source_token]
      source_remote_url = settings['git_remote_url']
      source_gitlab_api_version = settings['gitlab_api_v4'] ? 4 : 3
      if import_urls
        success_urls = []
        error_projects = []
        import_urls.each do |import_url|
          namespace = params[:namespace]
          if import_url.empty? || namespace.empty?
            flash.now[:error] = 'Parameters is empty'
            return
          end
          uri = URI(import_url)
          uri.userinfo = "oauth2:#{access_token}"
          source_path = uri.path
          source_path_slash_rindex = source_path.rindex('/')
          source_path_dot_rindex = source_path.rindex('.')
          new_project_name = source_path[source_path_slash_rindex + 1, source_path_dot_rindex - 1 - source_path_slash_rindex]
          begin
            res = g.create_project new_project_name, :import_url => uri.to_s, :visibility => 'private', :namespace_id => namespace
            http_url_to_repo = res.http_url_to_repo
            success_urls.append http_url_to_repo

            source_project_namespace = ERB::Util.url_encode(source_path[1, source_path_dot_rindex - 1])
            Net::HTTP.post(URI.join(source_remote_url, "/api/v#{source_gitlab_api_version}/projects/#{source_project_namespace}/archive?access_token=#{access_token}"), {})
          rescue => ex
            error_projects.append new_project_name
            logger.error {"GitLab Project Generater: Project '#{new_project_name}' has error: #{ex.message}"}
          end
        end
        if error_projects.empty?
          flash.now[:notice] = "Create project success, Url is: #{success_urls.join ","}"
        elsif success_urls.empty?
          flash.now[:error] = "Create project fail, Error Project is: #{error_projects.join ","}"
        else
          flash.now[:warning] = "Create project partially success, Successful Url is: #{success_urls.join ","}, Error Project is: #{error_projects.join ","}"
        end
      end
    end
    begin
      namespaces_res = g.namespaces
      @namespaces = namespaces_res.auto_paginate
    rescue
      flash.now[:error] = '无法获取Gitlab Namespace，请尝试重新授权登录'
    end
  end

  def getprojects
    gitlab_token_value = session[:gitlab_source_token]
    unless gitlab_token_value
      return render(:json => {:message => '尚未获取源Gitlab的Token，请先获取Gitlab OAuth授权'})
    end

    remote_url = settings['git_remote_url']
    gitlab_api_v4 = settings['gitlab_api_v4']

    gitlab_api_version = gitlab_api_v4 ? 4 : 3

    if !gitlab_token_value || gitlab_token_value.empty?
      return render(:json => {success: false, message: "No Token"})
    end

    g = Gitlab.client(endpoint: URI.join(remote_url, "/api/v#{gitlab_api_version}").to_s, private_token: gitlab_token_value)

    begin
      g_projects = g.projects(per_page: 100).auto_paginate
      render(:json => g_projects)
    rescue => ex
      render(:json => {:message => "获取项目失败：#{ex.message}"})
    end
  end

  def gitlab_oauth
    redirect_to oauth_client.auth_code.authorize_url(:redirect_uri => oauth_callback_url)
  end

  def gitlab_oauth_callback
    if params[:error]
      flash[:error] = params.to_s
      redirect_to project_generater_path
    else
      token = oauth_client.auth_code.get_token(params[:code], :redirect_uri => oauth_callback_url)
      session[:gitlab_source_token] = token.token
      redirect_to project_generater_path
    end
  end

  def oauth_client
    @client ||= OAuth2::Client.new(settings['client_id'], settings['client_secret'],
                                   :token_method => :post,
                                   :site => settings['git_remote_url'],
                                   :authorize_url => settings['git_remote_url'] + '/oauth/authorize',
                                   :token_url => settings['git_remote_url'] + '/oauth/token'
    )
  end

  def settings
    @settings ||= Setting.plugin_redmine_gitlab_project_generater
  end

  private

  def oauth_callback_url
    @oauth_callback_url ||= (Setting.protocol + "://" + Setting.host_name + project_generater_oauth_callback_path)
  end
end
