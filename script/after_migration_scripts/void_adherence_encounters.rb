=begin

Creator :     Precious Ulemu Bondwe
Date    :     2013-08-28 
Purpose :     To void all adherence encounters with their corresponding observations. 
              This allows recalculation of adherence in case adherence was not calculated properly. 
=end

def start

adherence_encounters = Encounter.find(:all, :conditions => ["encounter_type = ? AND voided = 0", 68])
counter = 0
puts ">>>>>>>Starting<<<<<<<"
	adherence_encounters.each do |adh_enc|
		#puts "#{adh_enc.to_yaml}"
		counter = counter + 1

		obs = Observation.find(:all, :conditions => ["encounter_id = ? AND voided = 0", adh_enc.encounter_id])
		obs.each do |aObs|
			if aObs.voided != true
				aObs.void
			end
		end

		if adh_enc.voided != true
			adh_enc.void
		end
		#adh_enc.save
		puts ">>>>> #{adherence_encounters.length - counter}....of....#{adherence_encounters.length}.....remaining!"
	end
puts ">>>>>> Finished <<<<<<"
end
start
