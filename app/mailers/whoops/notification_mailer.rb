class Whoops::NotificationMailer < ActionMailer::Base
  default :from => 'no-reply@example.com',
          :return_path => 'system@example.com'

  def event_notification(event_group, *addresses)
    @event_group = event_group
    @addresses = addresses
    # better option?  http://excid3.com/blog/change-actionmailer-email-url-host-dynamically/
    @url = "http://#{Rails.configuration.action_mailer.default_url_options[:host]}/event_groups/#{@event_group.id}/events"
    
    mail(
      :to      => addresses.join(", "),
      :subject => "Whoops Notification | #{event_group.service}: #{event_group.environment}: #{event_group.message}"
    )
  end
end