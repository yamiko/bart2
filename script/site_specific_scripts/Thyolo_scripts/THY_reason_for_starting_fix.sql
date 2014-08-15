/*
Developer	:	Precious Bondwe
Purpose		: 	Assign value_coded_name_id values to Reason for ART Eligibility
				observations that only have value_coded
Site		:	Thyolo District Hospital
*/

UPDATE obs 
SET 
    value_coded_name_id = CASE value_coded
        WHEN 8263 THEN 11338
        WHEN 7051 THEN 9798
        WHEN 1067 THEN 1104
        WHEN 8208 THEN 11267
        WHEN 7047 THEN 9789
        WHEN 8376 THEN 11463
        WHEN 7048 THEN 9792
        WHEN 844 THEN 863
        WHEN 7052 THEN 9800
        WHEN 1169 THEN 1207
        WHEN 9389 THEN 12588
        WHEN 7048 THEN 9792
        WHEN 7049 THEN 9793
        WHEN 7052 THEN 9800
        WHEN 8207 THEN 11265
        WHEN 1107 THEN 1144
        WHEN 8262 THEN 11336
        WHEN 1755 THEN 1915
        WHEN 7561 THEN 10400
        WHEN 5632 THEN 11442
        WHEN 7046 THEN 9788
        ELSE NULL
    END
WHERE
    concept_id = 7563
        AND value_coded_name_id IS NULL
        AND voided = 0;
