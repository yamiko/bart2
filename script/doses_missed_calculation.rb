#calculating the doses missed value
def doses_missed(start_date = @start_date, end_date = @end_date)

	#loop through each patient with adherence encounter
	art_adherence = EncounterType.find_by_name('ART ADHERENCE').id
	pills_left_ids = [ConceptName.find_by_name("AMOUNT OF DRUG BROUGHT TO CLINIC").concept_id,
	ConceptName.find_by_name("AMOUNT OF DRUG REMAINING AT HOME").concept_id]
		
	encounters = Encounter.find(:all, :conditions => ["encounter_type = #{art_adherence}"], :limit => 500)#

	counter = 0
	encounters.map do |adherence|

		orders = PatientService.drug_given_before(adherence.patient, adherence.encounter_datetime)
   
		orders.map do |order| 
			amount_brought_to_clinic = 0
		
			adherence.observations.map do |obs|
				if pills_left_ids.include?(obs.concept_id) && order.order_id == obs.order_id
					amount_brought_to_clinic += obs.answer_string.to_i
				end

			end

			num_days = (adherence.encounter_datetime.to_date - order.start_date.to_date).to_i#/ (1000 * 60 * 60 * 24)

			if order.drug_order.quantity 
				order_quantity = order.drug_order.quantity
			else
				order_quantity = 0
			end

			expected_amount_remaining = (order_quantity - (num_days * order.drug_order.equivalent_daily_dose.to_i))

			if expected_amount_remaining == amount_brought_to_clinic
				doses_missed = 0
			else
				doses_missed = ((expected_amount_remaining - amount_brought_to_clinic) / order.drug_order.equivalent_daily_dose.to_i)#.to_i
				if doses_missed < 0
					doses_missed = doses_missed * -1
				else
					doses_missed
				end
		  end
						
			observation = Observation.new
			observation.person_id = adherence.patient_id
			observation.encounter_id = adherence.encounter_id
			observation.concept_id = ConceptName.find_by_name("MISSED HIV DRUG CONSTRUCT").concept_id
			observation.obs_datetime = adherence.encounter_datetime
			observation.value_numeric = doses_missed.to_i
			observation.order_id = order.order_id
			observation.location_id = adherence.location_id
			if observation.save
				counter += 1
			end
		end
	end
	return counter
end
