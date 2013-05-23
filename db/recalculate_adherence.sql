DELIMITER $$


DROP FUNCTION IF EXISTS recalculate_adherence $$
CREATE FUNCTION recalculate_adherence(start_date VARCHAR(10)) RETURNS VARCHAR(5)

BEGIN

  DECLARE done INT DEFAULT FALSE;
  DECLARE record_patient_id int;
  DECLARE record_drug_id int;
  DECLARE record_visit_date varchar(10);

  DECLARE records CURSOR FOR SELECT t3.person_id,t1.drug_inventory_id,DATE(t3.obs_datetime) 
        FROM drug_order t1 INNER JOIN orders t2 ON t2.order_id = t1.order_id INNER JOIN obs t3 ON t3.order_id = t2.order_id
        WHERE t3.concept_id = (SELECT concept_id FROM concept_name WHERE name ="AMOUNT OF DRUG BROUGHT TO CLINIC" LIMIT 1) 
        AND t3.obs_datetime <= DATE(start_date) 
        GROUP BY t3.person_id,obs_datetime,t3.obs_id;

  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE; 

  OPEN records;
  read_loop: LOOP
  FETCH records into record_patient_id,record_drug_id,record_visit_date;
    
    IF done THEN
      LEAVE read_loop;
    END IF;
    INSERT INTO ad_test (`adherence`) VALUES(adherence_cal(record_patient_id,record_drug_id,record_visit_date));
  END LOOP;
  CLOSE records;
  RETURN "done";
END$$

DELIMITER ;
