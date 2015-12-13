require 'jira'

module Versionify
  class Manager

    class UrlGenerator
      def initialize(project)
        @project = project
      end

      def version(version)
        "#{fetch(:versionify_jira_url)}/browse/#{@project.key}/fixforversion/#{version.id}"
      end
    end

    def initialize(context)
      @context = context

      options = {
          :username => fetch(:versionify_jira_username),
          :password => fetch(:versionify_jira_password),
          :site     => fetch(:versionify_jira_url),
          :context_path => '/',
          :auth_type => :basic
      }

      @client = JIRA::Client.new(options)
      @project = @client.Project.find(fetch(:versionify_jira_project_id))

      @url_generator = UrlGenerator.new(@project)
    end


    def create_version(name)
      @project.versions.each do |version|
        if version.name.equal?(name)
          puts "Specific version already exists"
          exit 1
        end
      end

      version = @client.Version.build
      version.save({
           'name' => name,
           'project' => @project.key
      })

      version.fetch

      version
    end


    def get_changelog(version)
      changelog = "Version: #{version.name}\n"
      changelog += "---------------------------------\n"
      changelog += "Issues:\n"
      @client.Issue.jql("fixVersion = #{version.name}").each do |issue|
        changelog += " - [#{issue.key}] - #{issue.summary}\n"
      end

      changelog
    end


    def find_issue_by_id(id)
      @client.Issue.find(id)
    end


    def get_opened_version
      @project.versions.select { |item| !item.released}[0]
    end


    def project
      @project
    end

    def generator
      @url_generator
    end


    def assign_to_version(issue, version)
      issue.save({'fields' => {'fixVersions' => [{'id': version.id}]}})

      self.transist_to(issue, fetch(:versionify_jira_relesable_status))

      issue
    end


    def transist_to(issue, state)
      transision_map = fetch(:versionify_jira_transision_map)

      if issue.status.id == state or !transision_map.key?(issue.status.id)
        return issue
      end

      transition = issue.transitions.build
      transition.save('transition' => {'id' => transision_map[issue.status.id]})

      issue.fetch

      self.transist_to(issue, state)
    end

  end

  class PodioPublisher
    def initialize
      Podio.setup(:api_key => fetch(:versionify_podio_api_key), :api_secret => fetch(:versionify_podio_api_secret))
      Podio.client.authenticate_with_credentials(fetch(:versionify_podio_username), fetch(:versionify_podio_password))
    end
  end

end
