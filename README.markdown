Installing Bart2

BART is an ART application written in Ruby on Rails and is intended as a web front end for OpenMRS for supporting Malawi's ART system. 
OpenMRS® is a community-developed, open-source, enterprise electronic medical record system framework. We've come together to specifically respond to those actively building and managing health systems in the developing world, where AIDS, tuberculosis, and malaria afflict the lives of millions. Our mission is to foster self-sustaining health information technology implementations in these environments through peer mentorship, proactive collaboration, and a code base that equals or surpasses proprietary equivalents. You are welcome to come participate in the community, whether by implementing our software, or contributing your efforts to our mission!
BART was developed by Baobab Health in Malawi, Africa. It is licensed under the GNU Lesser General Public License.
Requirements

Ubuntu/Debian OS 10.04 or later(operating system)
Firefox 11.0 or later(web browser)
Ruby 1.8.7(programming language)
Rubygems 1.3.7(ruby gem manager)
Rails 2.3.5(ruby web application framework)
Passenger 3.0 or later(web application server)
MySQL version 5 or later(database server)

Prerequisites

Before you begin the installation make sure you have the following installed on Ubuntu/Debian OS 10.04 or above:
Firefox  11.0 or above
Ruby 1.8.7
Rubygems 1.3.7
MySQL version 5 or above



Installation
Step 1: Ruby and main packages installation
Using your terminal run the following command:

sudo apt-get install ruby build-essential libopenssl-ruby ruby1.8-dev 
ruby-dev mysql-client mysql-server git-core libmysql-ruby 
libmysqlclient-dev unzip rubygems 

Check if the ruby version is the correct one by running: (ruby -v) expected 1.8.7

Step 2: Downgrade Rubygems

wget http://rubyforge.org/frs/download.php/70697/rubygems-1.3.7.zip 
unzip rubygems-1.3.7.zip
ruby rubygems-1.3.7/setup.rb 

Check if the rubygems version is the correct one by running: (gem -v)   expected 1.3.7 

Step 3: Install initial gems
Install bundler  using the following command: 
    
 sudo gem install bundler
Step 4: Clone and configure Bart2
In the same terminal window/shell run the following command:
git clone https://github.com/BaobabHealthTrust/bart2


Navigate to your bart2 root folder: 
cd bart2
create database.yml and application.yml files by the following commands:

cp config/database.yml.example config/database.yml
cp config/application.yml.example config/application.yml

Configure your database.yml.example with correct database parameters.
Configure your application.yml with the correct global application parameters.Proceeding screenshots can help:

             
    production:
                 adapter: mysql
                        database: your_database_name
                        username: your_database_username
                        password: your_database_password
                        host: localhost
                        pool: 500
      development:
                       adapter: mysql
                       database: your_database_name
                       username: your_database_username
                       password: your_database_passwor
                       host: localhost
                       pool: 500
       healthdata:
                       adapter: mysql
                       database: healthdata
                       username: your_database_username
                       password: your_database_password
                       host: localhost
                       pool: 500


Save and close the database.yml file.


Using your editor open the application.yml file and make sure it looks something like the following:

       healthdata:
                       create_from_remote: no
                       use.user.selected.activities: yes
                       filing.number.prefix: FN101,FN102
                       auto_set_appointment: true
                       records_per_page: 15
                       debugger_sorting_attribute: arv_number
                       logo: mw.gif




Save and close the application.yml file.


Step 5: Set Rails environment to development mode
In your bart2 root folder, run the command: 
export RAILS_ENV=development
Then run the command: 
bundle install or bundle install --local    

After the bundle has finished, run the database setup by running:

bundle exec script/initial_database_setup.sh development mpc

Step 6: Run the application

In the application root folder, run the command:

bundle exec passenger start -e production

Then open the link http://localhost:3000  in your Firefox browser. 
