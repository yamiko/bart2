class Notifications < ActionMailer::Base

  include SendGrid
  #default :from => "epics@baobabhealth.org"
  sendgrid_category :use_subject_lines
  sendgrid_enable   :ganalytics, :opentrack
  sendgrid_unique_args :key1 => Time.now, :key2 => Time.now
  
  def notify(subject,body,file_name)
	 sendgrid_category "Report"
	 sendgrid_unique_args :key2 => Time.now, :key3 => Time.now
     recipients 'fuvu.chirwa@gmail.com'
     subject subject
     from 'epics@baobabhealth.org'
     content_type 'text/html'
     part "text/html" do |p|
       p.body = render_message("Test", :message =>"#{body}")
     end

    # attachment :content_type => "application/pdf",
     #           :body => File.read("/tmp/#{file_name}")
     @subject = subject
     @email_body = body
   #  mail(:to => 'fuvu.chirwa@gmail.com', :subject => @subject)
  end

  def email_error(subject)
    sendgrid_category "Email Error"
	  sendgrid_unique_args :key2 => Time.now, :key3 => Time.now
    @subject = subject
    mail(:to => "fuvu.chirwa@gmail.com", :subject => @subject)
  end

end
