
def initialize
  source_db= YAML.load(File.open(File.join(RAILS_ROOT, "config/database.yml"), "r"))['bart2']["database"]
  started_at = Time.now.strftime("%Y-%m-%d-%H%M%S")
end

def write_sql(hash,table)

 $temp_ft1_outfile = File.open("./migration_output/flat_table_1-" + started_at + ".sql", "w")
 $temp_ft2_outfile = File.open("./migration_output/flat_table_2-" + started_at + ".sql", "w") 
 $temp_cft_outfile = File.open("./migration_output/cohort_flat_table-" + started_at + ".sql", "w")
end

def start
 initialize
end
