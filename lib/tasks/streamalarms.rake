namespace :streamalarms do

  desc "Alert all users who subscribed to a stream if it contains new messages"
  task :send => :environment do
    # Go through every stream that has enabled alerts.
    Stream.all_with_enabled_alerts.each do |stream_id|
      stream = Stream.find(stream_id)

      # Skip if limit or timespan is not set.
      if stream.alarm_limit.blank? or stream.alarm_timespan.blank?
        puts "Stream >#{stream.title}< has enabled alarms with users but no limit or timepspan set. Skipping."
        next
      end

      check_since = stream.alarm_timespan.minutes.ago
      puts "Stream >#{stream.title}< has enabled alarms. (max #{stream.alarm_limit} msgs/#{stream.alarm_timespan} min) Checking for message count since #{check_since}"

      # Check if above limit.
      count = Stream.message_count_since(stream_id, check_since.to_i)
      if count > stream.alarm_limit
        subscribers = AlertedStream.all_subscribers(stream)
        puts "\t#{count} messages: Above limit! Sending alarm to #{subscribers.count} subscribed users."

        # Build email body.
        body = "# Stream >#{stream.title}< has #{count} new messages in the last #{stream.alarm_timespan} minutes. Limit: #{stream.alarm_limit}"

        # Send messages.
        subscribers.each do |subscriber|
          begin
            Pony.mail(
              :to => subscriber,
              :from => Configuration.streamalarm_from_address,
              :subject => "#{Configuration.streamalarm_subject} (Stream: #{stream.title})",
              :body => body,
              :via => Configuration.email_transport_type,
              :smtp => Configuration.email_smtp_settings, # Only used when :via => :smtp
            )
            puts "\t[->] #{subscriber}"
          rescue => e
            puts "\t [!!] #{subscriber} (#{e.to_s.delete("\n")})"
          end
        end
      else
        puts "\t#{count} messages: Not above limit."
      end
       
      stream.last_alarm_check = Time.now
      stream.save
    end

    puts "All done."
  end
end
