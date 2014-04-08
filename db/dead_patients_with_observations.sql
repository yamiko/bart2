
/* Updating patients with visits after death */

UPDATE person SET death_date = NULL, dead = 0 
WHERE person_id IN (SELECT DISTINCT(e.patient_id) FROM earliest_start_date e 
INNER JOIN obs o ON o.person_id = e.patient_id
WHERE e.death_date IS NOT NULL 
AND o.voided = 0
AND DATE(o.obs_datetime) > DATE(e.death_date));




SELECT p.patient_id, current_state_for_program(p.patient_id, 1, '#{end_date}') AS state, c.name as status FROM patient p
                                INNER JOIN  program_workflow_state pw ON pw.program_workflow_state_id = current_state_for_program(p.patient_id, 1, '#{end_date}')
                                INNER join earliest_start_date e ON e.patient_id = p.patient_id
                                INNER JOIN concept_name c ON c.concept_id = pw.concept_id
                                WHERE earliest_start_date BETWEEN '#{start_date}' AND '#{end_date}'
                                AND  name = '#{outcome}'
