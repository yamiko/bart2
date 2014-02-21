class ValidationRule < ActiveRecord::Base
  @dispensed_id = ConceptName.find_by_name('PILLS DISPENSED').concept_id
  def self.dispensation_without_prescription(end_date = Date.today)
     unprescribed = Observation.find_by_sql("
                                  SELECT DISTINCT(person_id)  from obs
                                  WHERE (order_id <=> NULL)
                                  AND concept_id = #{@dispensed_id}
                                  AND voided = 0;").length
     return unprescribed
  end

  def self.prescrition_without_dispensation(end_date = Date.today)
    undispensed = Order.find_by_sql("
                                    SELECT DISTINCT(patient_id) FROM orders
                                    WHERE NOT EXISTS (SELECT order_id FROM obs WHERE order_id = orders.order_id
                                    AND concept_id = #{@dispensed_id} and  voided = 0)
                                    AND orders.voided = 0")
    return undispensed.length
  end

  def self.dispensation_without_appointment(end_date = Date.today)
    no_appointment = Observation.find_by_sql("
                                    SELECT DISTINCT(person_id) FROM obs
                                    WHERE concept_id = #{@dispensed_id}
                                    AND voided = 0
                                    AND person_id NOT IN
                                    (SELECT person_id FROM obs o
                                    INNER JOIN encounter e ON o.person_id = e.patient_id
                                    INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type
                                    WHERE et.name = 'Appointment'
                                    AND o.obs_datetime = obs_datetime
                                    AND o.person_id = person_id
                                    AND o.voided = 0)").length
    return no_appointment

  end

end
