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
      version_name = args[:version] || "#{fetch(:stage)}-" + Time.now.strftime("%Y%m%d_%H%M")
      version = manager.create_version(version_name)
      version_url = manager.generator.version(version)

      puts "Project: #{manager.project.name} [#{manager.project.key}]"
      puts "Created version: #{version.name} [#{version.id}]"
      puts "URL: #{version_url}"

      Rake::Task['versionify:auto_assign'].invoke
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

    puts "Issue #{issue.key} assigned to version: #{version.name}"
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

    commits.scan(/\w{2,3}\-\d+/).each do |issue_id|
      issue = manager.find_issue_by_id(issue_id)
      manager.assign_to_version(issue, version)

      puts "Issue #{issue.key} assigned to version: #{version.name}"
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
end

namespace :load do
  task :defaults do
    file = File.read(File.expand_path('~/.versionify'))
    settings = JSON.parse(file)

    set :versionify_podio_api_key, settings['podio']['api_key']
    set :versionify_podio_api_secret, settings['podio']['api_secret']
    set :versionify_podio_username, settings['podio']['username']
    set :versionify_podio_password, settings['podio']['password']
    set :versionify_podio_space_id, settings['podio']['space_id']
    set :versionify_podio_notify, ['@Team']

    set :versionify_jira_url, settings['jira']['url']
    set :versionify_jira_username, settings['jira']['username']
    set :versionify_jira_password, settings['jira']['password']
    set :versionify_jira_project_id, 'PRO'
    set :versionify_jira_transision_map, {'10005' => 11, '3' => 21, '10435' => 31, '10434' => 91, '10436' => 111, '10432' => 61}
    set :versionify_jira_relesable_status, 10432
    set :versionify_jira_final_status, 10433

    set :versionify_cap_prepare_to, 'staging'
    set :versionify_cap_release_to, 'prod'

    set :versionify_slack_prepare_channel, '#test'
    set :versionify_slack_release_channel, '#test'
  end
end
