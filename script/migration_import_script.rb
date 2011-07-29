require 'migrator'

Thread.abort_on_exception = true

puts "----- Starting Import Script at - #{Time.now} -----"

@import_path = 	'/tmp/migrator'
@bart_url = 'admin:test@localhost:3000'
@file_names = 	{
				'general_reception.csv' =>'ReceptionImporter',
				'update_outcome.csv'=>'OutcomeImporter',
			 	'give_drugs.csv'=>'DispensationImporter',
				'art_visit.csv'=> 'ArtVisitImporter',
			 	'hiv_first_visit.csv'=>'ArtInitialImporter',
				'date_of_art_initiation.csv'=>'ArtInitialImporter',
			 	'height_weight.csv'=>'VitalsImporter',
				'hiv_staging.csv'=>'HivStagingImporter',
				'hiv_reception.csv'=>'ReceptionImporter'
				}
threads = []
wait_threads = []
special_case_imports = ['give_drugs.csv','update_outcome.csv']

def import_encounters(afile,importer)
	puts "-----Starting #{afile} importing - #{Time.now}"

	aImporter = ReceptionImporter.new(@import_path) if importer == 'ReceptionImporter'
	aImporter = OutcomeImporter.new(@import_path) if importer == 'OutcomeImporter'
	aImporter = DispensationImporter.new(@import_path) if importer == 'DispensationImporter'
	aImporter = ArtVisitImporter.new(@import_path) if importer == 'ArtVisitImporter'
	aImporter = ArtInitialImporter.new(@import_path) if importer == 'ArtInitialImporter'
	aImporter = VitalsImporter.new(@import_path) if importer == 'VitalsImporter'
	aImporter = HivStagingImporter.new(@import_path) if importer == 'HivStagingImporter'

	aImporter.create_encounters(afile,@bart_url)

	puts "-----#{afile} imported - #{Time.now}"
end

import_encounters('general_reception.csv','ReceptionImporter')
import_encounters('hiv_first_visit.csv','ArtInitialImporter')
import_encounters('date_of_art_initiation.csv','ArtInitialImporter')
import_encounters('height_weight.csv','VitalsImporter')
import_encounters('hiv_staging.csv','HivStagingImporter')
import_encounters('hiv_reception.csv','ReceptionImporter')
import_encounters('update_outcome.csv','OutcomeImporter')
import_encounters('art_visit.csv', 'ArtVisitImporter')
import_encounters('give_drugs.csv','DispensationImporter')

=begin
Dir.entries(@import_path).each do |filename|
	next if special_case_imports.include?(filename)
	next unless @file_names.keys.include?(filename)
	threads << Thread.new(filename) do |wrk|
		import_encounters(filename,@file_names[filename])
	end
end
threads.each {|thread| thread.join}

special_case_imports.each do |sci|
	wait_threads << Thread.new(sci) do |t|
		import_encounters(sci,@file_names[sci])
	end
end
wait_threads.each {|thread| thread.join}
=end

puts "----- Finished Import Script at - #{Time.now} -----"

