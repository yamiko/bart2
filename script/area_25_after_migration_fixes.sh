#!/bin/bash

usage(){
  echo "Usage: $0 ENVIRONMENT"
  echo
  echo "ENVIRONMENT should be: development|test|production"
} 

ENV=$1

if [ -z "$ENV" ]; then
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

echo "fixing adherence observations"
script/runner script/area_25_scripts/fix_adherence_obs.rb

echo "recalculating adherence"
script/runner script/area_25_scripts/recalculate_adherence_area_25.rb

echo "fixing the earliest start date"
script/runner script/area_25_scripts/earliest_start_date_fix_on_area_25.rb

echo "fixing duplicate ART Visit and HIV staging encounters"
script/runner script/area_25_scripts/fix_for_duplicate_encounters_on_export.rb
script/runner script/area_25_scripts/fix_for_duplicate_hiv_staging.rb

echo "voiding ART visit and HIV staging duplicate encounters"
script/runner script/area_25_scripts/void_duplicates.rb
