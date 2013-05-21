#!/usr/bin/env ruby -wKU

module Scout
  class Command
    class Install < Command
      def run
        create_pid_file_or_exit

        abort usage unless $stdin.tty?
        
        puts <<-END_INTRO.gsub(/^ {8}/, "")
        === Scout Installation Wizard ===
        END_INTRO

        key = @args.first || get_key_from_stdin

        puts "\nAttempting to contact the server..."
        begin
          Scout::Server.new(server, key, history, log, server_name, @http_proxy, @https_proxy, @roles, @hostname) do |scout|
            scout.fetch_plan
            scout.run_plugins_by_plan
          end

          create_cron_script(key) if cron_script_required?

          puts <<-END_SUCCESS.gsub(/^ {10}/, "")
          Success!

          Now, you must setup Scout to run on a scheduled basis.

          Run `crontab -e`, pasting the line below into your Crontab file:

          * * * * * #{cron_command(key)}

          For help setting up Scout with crontab, please visit:

            http://scoutapp.com/help#cron

          END_SUCCESS
        rescue SystemExit
          puts $!.message
          puts <<-END_ERROR.gsub(/^ {10}/, "")

          Failed. 
          For more help, please visit:

          http://scoutapp.com/help

          END_ERROR
        end
      end

      private

        def create_cron_script(key)
          cron_script = File.join(config_dir, "scout_cron.sh")
          File.open(cron_script, 'w') do |file|
            file.puts '#! /usr/bin/env bash'
            file.puts

            if Environment.rvm?
              file.puts '# Loading the RVM Environment files.'
              file.puts "source #{Environment.rvm_path}\n"
            end

            if Environment.bundler?
              file.puts '# Changing directories to your rails project.'
              file.puts "cd #{`pwd`}\n"

              file.puts '# Call Scout and pass your unique key.'
              file.puts "bundle exec scout #{key}"
            else
              file.puts '# Call Scout and pass your unique key.'
              file.puts "scout #{key}"
            end
          end
        end

        def cron_command(key)
          if cron_script_required?
            "#{config_dir}/scout_cron.sh"
          else
            "#{`which scout`.strip} #{key}"
          end
        end

        def cron_script_required?
          Environment.rvm? || Environment.bundler?
        end

        def get_key_from_stdin
          puts <<-END_GET_KEY.gsub(/^ {10}/, "")
          You need the 40-character alphanumeric key displayed on the account page.

          Enter the Key:
          END_GET_KEY
          key = gets.to_s.strip
        end
    end
  end
end
