namespace :release do

  desc 'Prepare new release'
  task :prepare do
    begin
      options = {
          :username => fetch(:releases_jira_username),
          :password => fetch(:releases_jira_password),
          :site     => fetch(:releases_jira_url),
          :context_path => '/',
          :auth_type => :basic
      }

      client = JIRA::Client.new(options)
      project = client.Project.find(fetch(:releases_project_id))

      project.versions.each do |version|
        puts version
      end
    rescue CapistranoReleases::GeneralError => e
      logger.error e.message
    end
  end

end

namespace :load do
  task :defaults do
    set :releases_project_id, 'WEB'
    set :releases_jira_url, ''
    set :releases_jira_username, ''
    set :releases_jira_password, ''
  end
end