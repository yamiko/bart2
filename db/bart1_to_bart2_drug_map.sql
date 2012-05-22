USE bart2;

DROP TABLE IF EXISTS `bart1_to_bart2_drug_map`;

CREATE TABLE  `bart1_to_bart2_drug_map` (
  `bart1_id` int(11) NOT NULL DEFAULT '0',
  `bart2_id` int(11) NOT NULL,
  PRIMARY KEY (`bart1_id`),
  KEY `bart2_id` (`bart2_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

INSERT INTO `bart1_to_bart2_drug_map`(`bart1_id`, `bart2_id`) VALUES
(1,738),
(2,91),
(5,2),
(6,3),
(7,11),
(8,39),
(9,22),
(10,40),
(11,9),
(12,739),
(13,10),
(14,14),
(16,297),
(17,73),
(18,614),
(22,42),
(51,30),
(56,72),
(57,73),
(59,731),
(148,734);
