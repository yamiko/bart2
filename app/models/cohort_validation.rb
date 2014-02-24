class CohortValidation
    
	attr_accessor :cohort_object

	def initialize(cohort_obj)

		self.cohort_object = cohort_obj
	
	end

	def get_all_differences
	 
	 #This code runs all methods that start with 'validate_' 
	 #And returns a hash of all return values from such methods
	 #By Kenneth Kapundi
	 

		differences = {}
		(self.class.instance_methods(false) - Object.methods).each do |method|
			next if !method.match(/^validate\_/) 
			validation = method.sub(/^validate\_/, "").humanize
			differences[validation] = self.send(method) unless validation.blank?
		end

		return differences
	end
	
	def validate_kaposis_sarcoma_greator_than_total
		
		return	(self.cohort_object['Kaposis Sarcoma'].length > self.cohort_object['Newly total registered'].length)	
	end
				
	def validate_cumulative_kaposis_sarcoma_greator_than_total

		return (self.cohort_object['Total Kaposis Sarcoma'].length > self.cohort_object['Total registered'].length)	
	end 
	  
end

