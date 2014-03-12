class Notications < ActionMailer::Base
  include SendGrid
  #default :from => "epics@baobabhealth.org"
  sendgrid_category :use_subject_lines
  sendgrid_enable   :ganalytics, :opentrack
  sendgrid_unique_args :key1 => Time.now, :key2 => Time.now

  def notify(contact,subject,body,file_name)
    #raise smtp_settings.to_yaml
    sendgrid_category "Report"
	  sendgrid_unique_args :key2 => Time.now, :key3 => Time.now

    subject   '#{subject}'
    recipients '#{contact}'
    from       'epics@baobabhealth.org'
    sent_on    Date.today
    #sent_at    Time.now
    body       '#{body}'
    attachment :content_type => "application/pdf",
               :body => File.read("#{file_name}")

  end

  def email_error(subject)
    sendgrid_category "Email Error"
	  sendgrid_unique_args :key2 => Time.now, :key3 => Time.now
    @subject = subject
    mail(:to => "epics@baobabhealth.org", :subject => @subject)
  end

end
