require 'jira'
require 'podio'
require 'json'

module Versionify
  class Manager

    class UrlGenerator
      def initialize(project)
        @project = project
      end

      def version(version)
        "#{fetch(:versionify_jira_url)}/browse/#{@project.key}/fixforversion/#{version.id}"
      end

      def issue(issue)
        "#{fetch(:versionify_jira_url)}/browse/#{issue.key}"
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

      @generator = UrlGenerator.new(@project)
      @podio = PodioPublisher.new(@project)
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
      if version.nil?
        puts "No active version"
        return
      end

      changelog = ""
      @client.Issue.jql("fixVersion = #{version.name}").each do |issue|
        changelog += " - [#{issue.key}](#{@generator.issue(issue)}) - #{issue.summary}\n"
      end

      changelog
    end


    def find_issue_by_id(id)
      @client.Issue.find(id)
    end


    def get_opened_version
      @project.versions.select { |item| !item.released}[0]
    end

    attr_accessor :project
    attr_accessor :podio
    attr_accessor :generator


    def assign_to_version(issue, version)
      if issue.save({'fields' => {'fixVersions' => [{'id' => version.id}]}})
        puts "Issue #{issue.key} assigned to version: #{version.name}"

        issue.fetch
        self.transist_to(issue, fetch(:versionify_jira_relesable_status))
      else
        puts "Failed to assign given issue (#{issue.key}) to version: #{version.id}"
      end

      issue
    end


    def transist_to(issue, state)
      transision_map = fetch(:versionify_jira_transision_map)

      if issue.status.id == state or !transision_map.key?(issue.status.id)
        return issue
      end

      transition = issue.transitions.build
      unless transition.save('transition' => {'id' => transision_map[issue.status.id]})
        puts "Failed to perform transition"
        return
      end

      issue = self.find_issue_by_id(issue.key)

      self.transist_to(issue, state)
    end

    def announce(message, version)
      response = @client.get(
          "/rest/api/2/version/#{version.id}/remotelink"
      )

      links = JSON.parse(response.body)['links']

      if links.each { |link| link.key?('podio_status_id') }.length == 0
        podio_status = @podio.publish(message)

        @client.post(
            "/rest/api/2/version/#{version.id}/remotelink",
            {:podio_status_id => podio_status}.to_json
        )
      else
        podio_link = links.detect { |link| link['link'].key?('podio_status_id') }
        podio_id = podio_link['link']['podio_status_id']
        @podio.comment(podio_id, 'test')
      end

      if links.each { |link| link.key?('slack') }.length == 0

      end

    end
  end

  class PodioPublisher
    def initialize(project)
      @project = project

      Podio.setup(
          :api_key => fetch(:versionify_podio_api_key),
          :api_secret => fetch(:versionify_podio_api_secret)
      )

      Podio.client.authenticate_with_credentials(
          fetch(:versionify_podio_username),
          fetch(:versionify_podio_password)
      )
    end

    def publish(message)
      Podio::Status.create(
        fetch(:versionify_podio_space_id), {
          :value => message
        }
      )
    end

    def comment(status_id, message)
      Podio::Comment.create(
        'status',
        status_id, {
          :value => message
        })
    end
  end


  class SlackPublisher
    def initialize(project)
      @project = project


    end

    def publish(message)

    end
  end

end
