class CohortValidation
    
	attr_accessor :cohort_object

	def initialize(cohort_obj)

		self.cohort_object = cohort_obj
	
	end

	def get_all_differences

		differences = {}
		(self.class.instance_methods(false) - Object.methods).each do |method|
			next if !method.match(/^validate\_/) 
			validation = method.sub(/^validate\_/, "")
			differences[validation] = self.send(method)
		end

		return differences
	end
			   
end

