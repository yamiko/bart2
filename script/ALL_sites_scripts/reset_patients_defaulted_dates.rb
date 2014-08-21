#
# Usage: sudo script/runner -e <ENV> script/patient_defaulted_dates.rb
# 
# Default ENV is development
# e.g.: script/runner -e production script/reset_views.rb 
#       script/runner script/reset_views.rb


MY_ENV = ARGV[1]
MY_ENV = 'development' unless MY_ENV =~ /development|production|test/

puts "Reseting patients_defaulted_dates in #{MY_ENV} environment"

puts 'Reverting patients_defaulted_dates'
output = `bundle exec rake db:migrate RAILS_ENV=#{MY_ENV}`
puts output


puts 'Resetting Patients Defaulted Dates..........'
PatientDefaultedDate.reset
