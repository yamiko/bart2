DELETE 
FROM bart2.patient_state 
WHERE patient_program_id IN (
                            SELECT patient_program_id
                            FROM bart2.patient_program bpp
                            INNER JOIN (SELECT p.patient_id
                                        FROM bart2.patient_program pp, bart2.patient_state ps, patient p 
                                        WHERE pp.patient_program_id = ps.patient_program_id 
                                            AND ps.state =7 AND p.patient_id = pp.patient_id 
                                            AND p.voided=0 AND pp.voided=0 AND ps.voided=0 
                                            AND p.date_created < '2012-01-01' AND ps.start_date <'2012-01-01' 
                                            AND p.patient_id NOT IN (SELECT r.patient_id 
                                                                     FROM bart1.patient_registration_dates r, patient p 
                                                                     WHERE r.patient_id = p.patient_id 
                                                                     AND p.date_created < '2012-01-01')
                                        GROUP BY patient_id) pat
                                 ON bpp.patient_id = pat.patient_id
                            WHERE bpp.program_id = 1
                            )
AND state = 7 ;