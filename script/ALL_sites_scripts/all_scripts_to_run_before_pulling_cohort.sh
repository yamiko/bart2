#!/bin/bash
###Runs all scripts that are supposed to be run before pulling cohort

usage(){
  echo "Usage: $0 ENVIRONMENT"
  echo
  echo "ENVIRONMENT should be: development|production"
} 

ENV=$1

if [ -z "$ENV" ] ; then
  usage
  exit
fi

set -x # turns on stacktrace mode which gives useful debug information

if [ ! -x config/database.yml ] ; then
  cp config/database.yml.example config/database.yml
fi

USERNAME=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['username']"`
PASSWORD=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['password']"`
DATABASE=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['database']"`
HOST=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['host']"`

now=$(date +"%F %T")
echo "start time : $now"

echo "Resetting Patient Defaulted Dates.............."
 RAILS_ENV=${ENV}
 script/runner script/ALL_sites_scripts/reset_patients_defaulted_dates.rb ${ENV}

echo "Recalculating Regimen Categories..............."
 RAILS_ENV=${ENV}
 script/runner script/ALL_sites_scripts/recalculate_given_regimens.rb ${ENV}

later=$(date +"%F %T")
echo "start time : $now"
echo "end time : $later"
