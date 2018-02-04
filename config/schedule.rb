Time.zone = "Pacific Time (US & Canada)"
# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

job_type :command, ":task :output"
job_type :rake,    "cd :path && :environment_variable=:environment  bundle exec rake :task --silent :output"
job_type :runner,  "cd :path && script/rails runner -e :environment ':task' :output"
job_type :script,  "cd :path && :environment_variable=:environment  bundle exec script/:task :output"


# every 3.hours do
#   rake 'import:make_items_sold', :cron_log => "/dev/null"
# end

# every 4.hours do
#   rake 'import:shopsense_items', :cron_log => "/dev/null"
# end

# every 9.hours do
#   rake 'import:items', :cron_log => "/dev/null"
# end

# every 12.hours do
#   rake 'import:slow_scraping_items', :cron_log => "/dev/null"
# end

# every 1.day, at: '12:00 am' do
#   rake 'import:cj_items', :cron_log => "/dev/null"
# end


# 5:00 pm PST
every 1.day, at: '12:00 am' do
  rake 'import:silent_notifications', :cron_log => "/dev/null"
end

# every 1.day, at: '2:00 am' do
#   rake 'import:more_info_slow_items', :cron_log => "/dev/null"
# end

# every 1.day, at: '3:00 am' do
#   rake 'import:link_share_items', :cron_log => "/dev/null"
# end

# every 1.day, at: '4:00 am' do
#   rake 'import:forever_items', :cron_log => "/dev/null"
# end

# every 1.day, at: '6:00 am' do
#   rake 'import:ebay_items', :cron_log => "/dev/null"
# end

# 7 am PST
# every 1.day, at: '2:00 pm' do
#   rake 'import:silent_notifications', :cron_log => "/dev/null"
# end

# every 1.day, at: '10:00 am' do
#   rake 'import:more_info_items', :cron_log => "/dev/null"
# end


every 1.day, at: Time.zone.parse('4:00 pm').in_time_zone('UTC') do
  rake 'import:push_notifications', :cron_log => "/dev/null"
end

# every 6.days do
#   rake 'import:open_images', :cron_log => "/dev/null"
# end

# every 36.hours do
#   rake "log:clear", :cron_log => "/dev/null"
# end
