require 'jira'
require 'podio'
require 'json'
require 'date'

module Versionify
  class Announcer
    def initialize()
      @listeners = []
    end

    def add(announcer)
      @listeners.append(announcer)
    end

    def announce(message)
      @listeners.each do |l|
        l.announce(message)
      end
    end
  end

    class Message
      def initialize(body, version, comment)
        @body = body
        @version = version
        @comment = comment
      end
    end

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

      @jira = JIRA::Client.new(options)
      @project = @jira.Project.find(fetch(:versionify_jira_project_id))

      @generator = UrlGenerator.new(@project)
      @podio = PodioPublisher.new(@project)
      @slack = SlackPublisher.new(@project)
    end


    def create_version(name)
      @project.versions.each do |version|
        if version.name.equal?(name)
          puts "Specific version already exists"
          exit 1
        end
      end

      version = @jira.Version.build
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
      @jira.Issue.jql("fixVersion = #{version.name}").each do |issue|
        changelog += " - [#{issue.key}](#{@generator.issue(issue)}) - #{issue.summary}\n"
      end

      changelog
    end


    def find_issue_by_id(id)
      @jira.Issue.find(id)
    end


    def get_opened_version
      @project.versions.select { |item| !item.released}[0]
    end

    attr_accessor :project
    attr_accessor :podio
    attr_accessor :generator


    def assign_to_version(issue, version)
      if issue.fixVersions.size > 0 and issue.fixVersions.detect { |v| v.name.to_s.eql? version.name.to_s }.nil?
        puts "Issue #{issue.key} already assigned to #{issue.fixVersions[0].name} version"
        return
      end

      if issue.save({'fields' => {'fixVersions' => [{'id' => version.id}]}})
        puts "Issue #{issue.key} assigned to version: #{version.name}"

        issue.fetch
        self.transist_to(issue, fetch(:versionify_jira_final_status))
      else
        puts "Failed to assign given issue (#{issue.key}) to version: #{version.id}"
      end

      issue
    end

    def release_version(version)
      @client.Issue.jql("fixVersion = #{version.name}").each do |issue|
        self.transist_to(issue, fetch(:versionify_jira_relesable_status))
      end

      current_time = DateTime.now
      version.save({'released' => true, 'releaseDate' => current_time.strftime "%Y-%m-%d"})
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

    def announce(message, version, comment = false)
      message = Message.new(message, version, comment)

      announcer = Announcer.new
      announcer.add(PodioAnnouncer.new(@podio, @jira))
      announcer.add(SlackAnnouncer.new(@slack, :versionify_slack_channel))

      announcer.announce(message)
    end
  end

  class PodioAnnouncer
    def initialize(podio_client, jira_client)
      @podio = podio_client
      @jira = jira_client
    end

    def announce(message)
      response = @jira.get(
          "/rest/api/2/version/#{message.version.id}/remotelink"
      )

      links = JSON.parse(response.body)['links']

      if links.each { |link| link.key?('podio_status_id') }.length == 0
        podio_status = @podio.publish(message.body)

        @jira.post(
            "/rest/api/2/version/#{message.version.id}/remotelink",
            {:podio_status_id => podio_status}.to_json
        )
      else
        if comment
          podio_link = links.detect { |link| link['link'].key?('podio_status_id') }
          podio_id = podio_link['link']['podio_status_id']
          @podio.comment(podio_id, message.body)
        end
      end
    end
  end

  class SlackAnnouncer
    def initialize(slack_client, channel)
      @slack = slack_client
      @channel = channel
    end

    def announce(message)
      @slack.publish(message.body)
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
      @channel = fetch(:versionify_slack_channel)
      @webbook_url = fetch(:versionify_slack_url)
    end

    def publish(message)
      self.post(message, @channel)
    end

    def comment(status_id, message)
      self.post(message, @channel)
    end

    def post(message, channel)
      # uri = URI.parse(@webbook_url)
      # http = Net::HTTP.new(uri.host, uri.port)
      # http.use_ssl = true
      # http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      # request = Net::HTTP::Post.new(uri.path)
      # request.add_field('Content-Type', 'application/json')
      # request.body = message
      # response = http.request(request)
    end
  end
end

module CapistranoDeploytags
  class Helper
    def self.git_tag_for(stage)
      "#{formatted_time}"
    end

    def self.formatted_time
      now = if fetch(:deploytag_utc, true)
              Time.now.utc
            else
              Time.now
            end

      now.strftime(fetch(:deploytag_time_format, "%Y.%m.%d-%H%M%S-#{now.zone.downcase}"))
    end

    def self.commit_message(current_sha, stage)
      if fetch(:deploytag_commit_message, false)
        deploytag_commit_message
      else
        "#{fetch(:user)} deployed #{current_sha} to #{stage}"
      end
    end
  end
end

def username
  ENV['DEPLOY_USER'] || fetch(:versionify_global_user) || `whoami`.chomp
end

def branch_name(default_branch)
  branch = ENV.fetch('BRANCH', default_branch)

  if branch == '.'
    # current branch
    `git rev-parse --abbrev-ref HEAD`.chomp
  else
    branch
  end
end

def commit()
  `git log -n 1 | head -n 1 | sed -e 's/^commit //' | head -c 8`.chomp
end

def active_version
  manager = Versionify::Manager.new(:self)
  version = manager.get_opened_version

  version.name
end
