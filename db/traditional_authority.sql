-- MySQL dump 10.13  Distrib 5.1.54, for debian-linux-gnu (i686)
--
-- Host: localhost    Database: openmrs17
-- ------------------------------------------------------
-- Server version	5.1.54-1ubuntu4

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `traditional_authority`
--

DROP TABLE IF EXISTS `traditional_authority`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `traditional_authority` (
  `traditional_authority_id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL DEFAULT '',
  `retired` tinyint(1) NOT NULL DEFAULT '0',
  `date_retired` datetime DEFAULT NULL,
  `retire_reason` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`traditional_authority_id`),
  UNIQUE KEY `name_index` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=1395 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `traditional_authority`
--

INSERT INTO traditional_authority (name, retired) VALUES
('Boghoyo',0),
('Bvumbwe',0),
('Chadza',0),
('Chakhumbira',0),
('Changata',0),
('Chapananga',0),
('Chigaru',0),
('Chikho',0),
('Chikowi',0),
('Chikulamayembe',0),
('Chikumbu',0),
('Chimaliro',0),
('Chimombo',0),
('Chimutu',0),
('Chimwala',0),
('Chindi',0),
('Chiseka',0),
('Chitera',0),
('Chitukula',0),
('Chiwere',0),
('Chulu',0),
('Dambe',0),
('Dzoole',0),
('Fukamapiri',0),
('Jalasi',0),
('Kabudula',0),
('Kabunduli',0),
('Kachindamoto',0),
('Kadewere',0),
('Kalembo',0),
('Kalolo',0),
('Kaluluma',0),
('Kalumba',0),
('Kalumbu',0),
('Kalumo',0),
('Kameme',0),
('Kanduku',0),
('Kanyenda',0),
('Kaomba',0),
('Kapelula',0),
('Kapeni',0),
('Kaphuka',0),
('Kapichi',0),
('Karonga',0),
('Kasakula',0),
('Kasisi',0),
('Kasumbu',0),
('Katuli',0),
('Katumbi',0),
('Katunga',0),
('Kawinga',0),
('Khombedza',0),
('Khongoni',0),
('Kilupula',0),
('Kuluunda',0),
('Kuntaja',0),
('Kunthembwe',0),
('Kuntumanji',0),
('Kwataine',0),
('Kyungu',0),
('Likoswe',0),
('Liwonde',0),
('Lundu',0),
('Mabuka',0),
('Mabulabo',0),
('Machinjili',0),
('Maganga',0),
('Makanjila',0),
('Makata',0),
('Makhwira',0),
('Malemia',0),
('Malenga',0),
('Malili',0),
('Mankhambira',0),
('Masasa',0),
('Maseya',0),
('Mazengera',0),
('Mkanda',0),
('Mkhumba',0),
('Mkumpha',0),
('Mlauli',0),
('Mlolo',0),
('Mlonyeni',0),
('Mlumbe',0),
('M\'Mbelwa',0),
('Mpama',0),
('Mpando',0),
('Mpherembe',0),
('Mponda',0),
('Msakambewa',0),
('Mtwalo',0),
('Mwabulambya',0),
('Mwadzama',0),
('Mwambo',0),
('Mwamlowe',0),
('Mwase',0),
('Mwenemisuku',0),
('Mwenewenya',0),
('Mzikubola',0),
('Mzukuzuku',0),
('Nankumba',0),
('Nazombe',0),
('Nchema',0),
('Nchilamwela',0),
('Ndamera',0),
('Ndindi',0),
('Ngabu',0),
('Njolomole',0),
('Nkalo',0),
('Nkanda',0),
('Nsabwe',0),
('Nsamala',0),
('Nthache',0),
('Nthalire',0),
('Nthiramanja',0),
('Nyambi',0),
('Pemba',0),
('Phambala',0),
('Santhe',0),
('Somba',0),
('Symon',0),
('Tambala',0),
('Tengani',0),
('Thomas',0),
('Timbiri',0),
('Usisya',0),
('Wasambo',0),
('Wimbe',0),
('Zolokere',0),
('Zulu',0);



