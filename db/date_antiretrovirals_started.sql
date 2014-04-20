DROP FUNCTION IF EXISTS date_antiretrovirals_started;                                          
                                                                                
DELIMITER $$                                                                     
CREATE FUNCTION date_antiretrovirals_started(set_patient_id INT) RETURNS DATE
BEGIN                                                                           
                                                                                
DECLARE date_started DATE;
DECLARE start_date_concept_id INT;

SET start_date_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'ART START DATE' LIMIT 1);
SET date_started = (SELECT value_datetime FROM obs WHERE concept_id = start_date_concept_id AND person_id = set_patient_id LIMIT 1);

if date_started is null then
SET start_date_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Date antiretrovirals started' LIMIT 1);
SET date_started = (SELECT value_datetime FROM obs WHERE concept_id = start_date_concept_id AND person_id = set_patient_id LIMIT 1);
end if;

if date_started is NULL then 
SET date_started = (SELECT earliest_start_date FROM earliest_start_date WHERE patient_id = set_patient_id LIMIT 1);
end if;

RETURN date_started;
END$$                                                                           
DELIMITER ;

