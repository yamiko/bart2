class NotificationsMailer < ActionMailer::Base
  def send_email
		recipients 'developers@baobabhealth.org'
		from 'bartbaobab@gmail.com' 
		subject "Bart2 Test Email" 
		sent_on Time.now 
		body 'Bart2 is the coolest ever!!!'
  end  
end
