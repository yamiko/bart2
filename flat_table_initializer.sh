#!/bin/bash
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

echo "Moving .sql files into backup folder"
FILES=db/flat_tables_init_output/*.sql
for f in $FILES
do
	echo "loading $f..."
	mv $f db/flat_tables_init_output/backup/.
done

echo "Exporting data into temporary files for tables 1 and 2"
 RAILS_ENV=${ENV}
 script/runner script/flat_table_initialization_scripts/batch_flat_table_initialization.rb ${ENV}

echo "Loading data from the temporary files into the database"
FILES=db/flat_tables_init_output/flat_table_*.sql
for f in $FILES
do
	echo "loading $f..."
	mysql --user=$USERNAME --password=$PASSWORD --host=$HOST  $DATABASE < $f
done

echo "Exporting data from the two tables for the flat_cohort_table"
RAILS_ENV=${ENV}  script/runner script/flat_table_initialization_scripts/batch_flat_cohort_table_load.rb ${ENV}

echo "Loading data from the temporary files into the database"
FILES=db/flat_tables_init_output/flat_cohort_table-*.sql
for f in $FILES
do
	echo "loading $f..."
	mysql --user=$USERNAME --password=$PASSWORD --host=$HOST  $DATABASE < $f
done

later=$(date +"%F %T")
echo "start time : $now"
echo "end time : $later"
