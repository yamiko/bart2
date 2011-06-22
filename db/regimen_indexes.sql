LOCK TABLES `regimen` WRITE;

ALTER TABLE `regimen` ADD COLUMN `regimen_index` INT(2)  NOT NULL DEFAULT 0 COMMENT 'To keep the index for the regimen' AFTER `concept_id`;

UPDATE `regimen` SET `regimen_index` = 1 WHERE `concept_id`=792;
UPDATE `regimen` SET `regimen_index` = 2 WHERE `concept_id`=1610;
UPDATE `regimen` SET `regimen_index` = 3 WHERE `concept_id`=7860;
UPDATE `regimen` SET `regimen_index` = 4 WHERE `concept_id`=7861;
UPDATE `regimen` SET `regimen_index` = 5 WHERE `concept_id`=2985;
UPDATE `regimen` SET `regimen_index` = 6 WHERE `concept_id`=2984;
UPDATE `regimen` SET `regimen_index` = 7 WHERE `concept_id`=7862;
UPDATE `regimen` SET `regimen_index` = 8 WHERE `concept_id`=2994;
UPDATE `regimen` SET `regimen_index` = 9 WHERE `concept_id`=7859;

UNLOCK TABLES;
