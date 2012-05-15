DELETE 
FROM bart2.patient_state
WHERE state = 1 AND date_created >= '2012-02-12';

DELETE 
FROM bart2.patient_state
WHERE state = 1 AND date_created >= '0000-00-00 00:00:00';

DELETE 
FROM bart2.patient_state
WHERE state = 7;

INSERT INTO bart2.patient_program (patient_id, program_id, date_enrolled, 
            creator, date_created, uuid, location_id)
SELECT patient_id, 1, date_created, creator, 
    date_created, (SELECT UUID()) AS uuid, 
    (SELECT property_value FROM bart2.global_property WHERE property = "current_health_center_id")
FROM bart2.patient 
WHERE voided = 0 AND patient_id NOT IN (SELECT patient_id FROM patient_program WHERE program_id = 1 AND voided = 0); 

INSERT INTO bart2.patient_state (patient_program_id, state, start_date, creator, date_created, uuid)
    SELECT pp.patient_program_id, 1, pp.date_enrolled, 1, pp.date_created, (SELECT UUID())
    FROM  bart2.patient p
        LEFT JOIN bart2.patient_program pp ON p.patient_id = pp.patient_id AND pp.program_id = 1 AND pp.voided = 0
        LEFT JOIN bart2.patient_state ps ON pp.patient_program_id = ps.patient_program_id AND ps.voided = 0
    WHERE ps.patient_state_id IS NULL
        AND p.voided = 0;


INSERT INTO patient_state (patient_program_id, state, start_date, creator, date_created, uuid)
(SELECT pp.patient_program_id, 7, DATE(obs1.obs_datetime), pp.creator, pp.date_created, (SELECT UUID())
FROM bart2.patient_program pp
INNER JOIN (SELECT obs.person_id, MIN(obs.obs_datetime) AS obs_datetime FROM bart2.drug_order d
    LEFT JOIN bart2.orders o ON d.order_id = o.order_id
    LEFT JOIN bart2.obs ON d.order_id = obs.order_id
    WHERE d.drug_inventory_id IN (SELECT drug_id FROM drug WHERE concept_id IN (SELECT concept_id FROM concept_set WHERE concept_set = 1085)) 
        AND quantity > 0
        AND obs.voided = 0
        AND o.voided = 0
    GROUP BY obs.person_id) obs1 ON pp.patient_id = obs1.person_id AND pp.program_id = 1 
GROUP BY pp.patient_id, DATE(obs1.obs_datetime));

UPDATE bart2.patient_program
    SET date_enrolled = (SELECT MIN(start_date)
                            FROM bart2.patient_state ps2 
                            WHERE ps2.patient_program_id = bart2.patient_program.patient_program_id);

UPDATE bart2.patient_state 
    SET start_date = (SELECT date_enrolled
                    FROM bart2.patient_program pp2 
                    WHERE pp2.patient_program_id = bart2.patient_state.patient_program_id)
    WHERE state = 1;

DROP TABLE IF EXISTS `temp_patient_list`;

CREATE TABLE `temp_patient_list` (
  `patient_program_id` int(11) NOT NULL DEFAULT '0',
  `start_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`patient_program_id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;


INSERT INTO temp_patient_list
SELECT patient_program_id, start_date
    FROM patient_state
    WHERE state = 7 ;

UPDATE bart2.patient_state 
    SET end_date = (SELECT start_date
                    FROM temp_patient_list pp
                    WHERE pp.patient_program_id = bart2.patient_state.patient_program_id)
    WHERE state = 1;

DROP TABLE IF EXISTS `temp_patient_list`;

INSERT INTO bart2.patient_state (patient_program_id, state, start_date, creator, date_created, uuid)
    SELECT pp.patient_program_id, 3, MIN(o.obs_datetime), 1, MIN(o.obs_datetime), (SELECT UUID())
        FROM bart1.obs o LEFT JOIN bart2.patient_program pp ON o.patient_id = pp.patient_id
        WHERE o.concept_id = 28 AND o.value_coded = 322 AND o.voided = 0
        GROUP BY o.patient_id;

DROP TABLE IF EXISTS `temp_patient_list`;

CREATE TABLE `temp_patient_list` (
  `patient_program_id` int(11) NOT NULL DEFAULT '0',
  `patient_id` int(11) NOT NULL DEFAULT '0',
  `start_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  PRIMARY KEY (`patient_program_id`),
  KEY (`patient_id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8;


INSERT INTO temp_patient_list (patient_program_id, patient_id, start_date)
SELECT ps.patient_program_id, pp.patient_id, ps.start_date
    FROM patient_state ps LEFT JOIN patient_program pp ON ps.patient_program_id = pp.patient_program_id
    WHERE state = 3 ;

UPDATE bart2.patient_state
    SET end_date = (SELECT start_date
                    FROM temp_patient_list pp
                    WHERE pp.patient_program_id = bart2.patient_state.patient_program_id)
    WHERE state = 7;

UPDATE bart2.patient_program
    SET date_completed = (SELECT start_date
                        FROM temp_patient_list pp
                        WHERE pp.patient_program_id = bart2.patient_program.patient_program_id)
    WHERE program_id = 1;

UPDATE person
    SET dead = 1, death_date = (SELECT start_date 
                                    FROM temp_patient_list t 
                                    WHERE t.patient_id = person.person_id)
    WHERE person_id IN (SELECT patient_id FROM temp_patient_list);

DROP TABLE IF EXISTS `temp_patient_list`;


