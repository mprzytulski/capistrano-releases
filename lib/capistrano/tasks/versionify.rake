require 'json'

namespace :versionify do
  desc 'Prepare new version (create new in Jira)'
  task :prepare, :version do |task, args|
    manager = Versionify::Manager.new(:self)

    version = manager.get_opened_version

    if version
      puts 'There is already opened version'
      Rake::Task['versionify:active_version'].invoke
    else
      version_name = args[:version] || "v" + Time.now.strftime("%Y%m%d_%H%M")
      version = manager.create_version(version_name)
      version_url = manager.generator.version(version)

      puts "Project: #{manager.project.name} [#{manager.project.key}]"
      puts "Created version: #{version.name} [#{version.id}]"
      puts "URL: #{version_url}"

      Rake::Task['versionify:auto_assign'].invoke
      Rake::Task['versionify:announce'].invoke
    end
  end


  desc 'Show changelog for given version (list of version tasks)'
  task :changelog do
    manager = Versionify::Manager.new(:self)

    version = manager.get_opened_version

    puts manager.get_changelog(version)
  end


  desc 'Assign given jira task to opened version'
  task :assign, :issue_id do |task, args|
    manager = Versionify::Manager.new(:self)

    issue = manager.find_issue_by_id(args[:issue_id])
    version = manager.get_opened_version

    manager.assign_to_version(issue, version)
    message = "[#{issue.key}](#{manager.generator.issue(issue)}) - #{issue.summary}\n"

    manager.announce(
      message,
      version,
      true
    )
  end


  desc 'Show active version'
  task :active_version do
    manager = Versionify::Manager.new(:self)
    version = manager.get_opened_version

    if version
      version_url = manager.generator.version(version)

      puts "Project: #{manager.project.name} [#{manager.project.key}]"
      puts "Active version: #{version.name} [#{version.id}]"
      puts "URL: #{version_url}"
    else
      puts 'No active version found'
    end
  end


  desc 'Auto assign tickets from commits'
  task :auto_assign do |task, args|
    manager = Versionify::Manager.new(:self)

    commits = `git log \`git describe --tags --abbrev=0\`..HEAD --oneline`

    version = manager.get_opened_version

    commits.scan(/\w{2,6}\-\d+/i).map(&:upcase).uniq.each do |issue_id|
      begin
        issue = manager.find_issue_by_id(issue_id)
        manager.assign_to_version(issue, version)
      rescue JIRA::HTTPError
        puts "Skipping unrecognized issue: #{issue_id}"
      end
    end
  end

  desc 'Announce new version'
  task :announce do
    manager = Versionify::Manager.new(:self)

    version = manager.get_opened_version

    message = "# #{fetch(:domain)} version announcement.\n\n"
    message += "New version: **#{version.name}** is being prepared for release.\n"
    message += "Changelog: \n"
    message += manager.get_changelog(version)

    manager.announce(
        message,
        version
    )
  end

  desc 'Deploy project'
  task :deploy do
    manager = Versionify::Manager.new(:self)

    version = manager.get_opened_version

    if version.nil?
      puts "No active version"
      return
    end

    is_prod = fetch(:stage).to_s.eql? fetch(:versionify_cap_release_to).to_s

    Rake::Task['deploy'].invoke

    message = is_prod ? "### New version of *#{fetch(:application)}* is live now!\n\n" : ""

    if is_prod
      version_url = manager.generator.version(version)
      message += "\n\n\n> Version has been marked as released: #{version_url}"
      message += "\n\n\n\n**Full changelog:** \n\n"
      message += manager.get_changelog(version)

      manager.release_version(version)
    else
      message += "Updated version **#{version.name}** of *#{fetch(:application)}* has been deployed to **#{fetch(:stage)}** on http://#{fetch(:domain)}"
    end

    manager.announce(
        message,
        version,
        true
    )
  end
end

namespace :load do
  task :defaults do
    path =  File.expand_path('~/.versionify')
    unless File.exist?(path)
      puts "Missing configuration file ~/.versionify"
      exit 1
    end

    file = File.read(File.expand_path('~/.versionify'))

    settings = JSON.parse(file)

    set :versionify_global_user, settings['global']['user']
    set :versionify_podio_api_key, settings['podio']['api_key']
    set :versionify_podio_api_secret, settings['podio']['api_secret']
    set :versionify_podio_username, settings['podio']['username']
    set :versionify_podio_password, settings['podio']['password']
    set :versionify_podio_space_id, 0
    set :versionify_podio_notify, ['@Team']

    set :versionify_jira_url, settings['jira']['url']
    set :versionify_jira_username, settings['jira']['username']
    set :versionify_jira_password, settings['jira']['password']
    set :versionify_jira_project_id, 'PRO'
    set :versionify_jira_transision_map, {'10005' => 11, '3' => 21, '4' => 71, '10435' => 31, '10434' => 91, '10436' => 111, '10432' => 61}
    set :versionify_jira_relesable_status, '10432'
    set :versionify_jira_final_status, '10433'

    set :versionify_cap_prepare_to, 'staging'
    set :versionify_cap_release_to, 'prod'

    set :versionify_slack_prepare_channel, settings['slack']['prepare_channel']
    set :versionify_slack_release_channel, settings['slack']['release_channel']
    set :versionify_slack_api_token, settings['slack']['webhook']
  end
end


namespace :deploy do
  task :disallow_robots do
    on roles(:web) do
      execute "cd #{fetch(:release_path)} && echo -e \"User-agent: *\\nDisallow: /\\n \" > web/robots.txt"
    end
  end
end
