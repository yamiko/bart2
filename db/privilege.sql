-- MySQL dump 10.13  Distrib 5.1.54, for debian-linux-gnu (i686)
--
-- Host: localhost    Database: bart
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
-- Table structure for table `privilege`
--

DROP TABLE IF EXISTS `privilege`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `privilege` (
  `privilege` varchar(50) NOT NULL DEFAULT '',
  `description` varchar(250) NOT NULL DEFAULT '',
  `uuid` char(38) NOT NULL,
  PRIMARY KEY (`privilege`),
  UNIQUE KEY `privilege_uuid_index` (`uuid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `privilege`
--

LOCK TABLES `privilege` WRITE;
/*!40000 ALTER TABLE `privilege` DISABLE KEYS */;
INSERT INTO `privilege` VALUES ('Add Allergies','Add allergies','0a301628-a2d3-4389-8caa-75ee7913327c'),('Add Cohorts','Able to add a cohort to the system','10ace684-b6c1-11e0-bc9e-544249e32ba2'),('Add Concept Proposals','Able to add concept proposals to the system','10acec60-b6c1-11e0-bc9e-544249e32ba2'),('Add Concepts','Able to add new terms to the concept dictionary.','10acee36-b6c1-11e0-bc9e-544249e32ba2'),('Add Encounters','Able to add new encounters?','10acefe4-b6c1-11e0-bc9e-544249e32ba2'),('Add FormEntry Archive','Allows the user to add the formentry archive','10acf192-b6c1-11e0-bc9e-544249e32ba2'),('Add FormEntry Error','Allows a user to add a formentry error item','10acf35e-b6c1-11e0-bc9e-544249e32ba2'),('Add FormEntry Queue','Allows user to add a queue item to database','10acf50c-b6c1-11e0-bc9e-544249e32ba2'),('Add Forms','Able to add new forms.','10acf6b0-b6c1-11e0-bc9e-544249e32ba2'),('Add Observations','Able to add clinical encounters to the repository.','10acf84a-b6c1-11e0-bc9e-544249e32ba2'),('Add Orders','Able to add clinical orders and procedures for a given patient.','10acf9ee-b6c1-11e0-bc9e-544249e32ba2'),('Add Patient Identifiers','Able to add patient identifiers','10acfb9c-b6c1-11e0-bc9e-544249e32ba2'),('Add Patient Programs','Able to add patients to programs','10acfd36-b6c1-11e0-bc9e-544249e32ba2'),('Add Patients','Able to add new patients to the system.','10acfeda-b6c1-11e0-bc9e-544249e32ba2'),('Add People','Able to add person objects','10ad007e-b6c1-11e0-bc9e-544249e32ba2'),('Add Problems','Add problems','9581a6d5-493f-42f0-9086-4f62922571e4'),('Add Relationships','Able to add relationships','10ad0218-b6c1-11e0-bc9e-544249e32ba2'),('Add Report Objects','Able to add report objects','10ad03a8-b6c1-11e0-bc9e-544249e32ba2'),('Add Reports','Able to add new reports.','10ad0542-b6c1-11e0-bc9e-544249e32ba2'),('Add Users','Able to add new users to the system.','10ad06dc-b6c1-11e0-bc9e-544249e32ba2'),('Analysis Shortcut','Shortcut to patient groups on homepage','10ad086c-b6c1-11e0-bc9e-544249e32ba2'),('Analyze','Work with patient groups','10ad0a06-b6c1-11e0-bc9e-544249e32ba2'),('Data Import','Allows user to access Data Import pages/functions','10ad0b8c-b6c1-11e0-bc9e-544249e32ba2'),('Delete Cohorts','Able to add a cohort to the system','10ad0d1c-b6c1-11e0-bc9e-544249e32ba2'),('Delete Concept Proposals','Able to delete concept proposals from the system','10ad0ed4-b6c1-11e0-bc9e-544249e32ba2'),('Delete Concepts','Able to remove concepts from the dictionary.','10ad1078-b6c1-11e0-bc9e-544249e32ba2'),('Delete Encounters','Able to void encounters from the repository.','10ad1226-b6c1-11e0-bc9e-544249e32ba2'),('Delete FormEntry Archive','Allows the user to delete a formentry archive','10ad13ca-b6c1-11e0-bc9e-544249e32ba2'),('Delete FormEntry Error','Allows a user to delete a formentry error item','10ad1582-b6c1-11e0-bc9e-544249e32ba2'),('Delete FormEntry Queue','Allows the user to delete formentry queue items','10ad1730-b6c1-11e0-bc9e-544249e32ba2'),('Delete Forms','Able to remove forms from the system.','10ad18e8-b6c1-11e0-bc9e-544249e32ba2'),('Delete Observations','Able to void observations for a given patient or encounter.','10ad1a8c-b6c1-11e0-bc9e-544249e32ba2'),('Delete Orders','Able to void orders from the system.','10ad1c3a-b6c1-11e0-bc9e-544249e32ba2'),('Delete Patient Identifiers','Able to delete patient identifiers','10ad1df2-b6c1-11e0-bc9e-544249e32ba2'),('Delete Patient Programs','Able to delete patients from programs','10ad1fa0-b6c1-11e0-bc9e-544249e32ba2'),('Delete Patients','Able to void patients from the system','10ad2158-b6c1-11e0-bc9e-544249e32ba2'),('Delete People','Able to delete objects','10ad2306-b6c1-11e0-bc9e-544249e32ba2'),('Delete Relationships','Able to delete relationships','10ad24a0-b6c1-11e0-bc9e-544249e32ba2'),('Delete Report Objects','Able to delete report objects','10ad2644-b6c1-11e0-bc9e-544249e32ba2'),('Delete Reports','Able to delete reports.','10ad27fc-b6c1-11e0-bc9e-544249e32ba2'),('Delete Users','Able to void user accounts from the system.','10ad29a0-b6c1-11e0-bc9e-544249e32ba2'),('Edit Allergies','Able to edit allergies','6907371e-6413-4f79-9d04-68d09b9f059e'),('Edit Cohorts','Able to add a cohort to the system','10ad2b30-b6c1-11e0-bc9e-544249e32ba2'),('Edit Concept Proposals','Able to edit concept proposals in the system','10ad2e78-b6c1-11e0-bc9e-544249e32ba2'),('Edit Concepts','Able to change attributes of existing terms.','10ad3030-b6c1-11e0-bc9e-544249e32ba2'),('Edit Encounters','Able to change information for preexisting encounters.','10ad31ca-b6c1-11e0-bc9e-544249e32ba2'),('Edit FormEntry Archive','Allows the user to edit a formentry archive','10ad336e-b6c1-11e0-bc9e-544249e32ba2'),('Edit FormEntry Error','Allows a user to edit a formentry error item','10ad351c-b6c1-11e0-bc9e-544249e32ba2'),('Edit FormEntry Queue','Allows the user to edit the formentry queue','10ad36ca-b6c1-11e0-bc9e-544249e32ba2'),('Edit Forms','Able to change preexisting forms.','10ad386e-b6c1-11e0-bc9e-544249e32ba2'),('Edit Observations','Able to change information relating to a particular observation.','10ad3a12-b6c1-11e0-bc9e-544249e32ba2'),('Edit Orders','Able to change information relating to an order.','10ad3bb6-b6c1-11e0-bc9e-544249e32ba2'),('Edit Patient Identifiers','Able to edit patient identifiers','10ad3d5a-b6c1-11e0-bc9e-544249e32ba2'),('Edit Patient Programs','Core Privilege','10ad3efe-b6c1-11e0-bc9e-544249e32ba2'),('Edit Patients','Able to change information about particular patients','10ad40a2-b6c1-11e0-bc9e-544249e32ba2'),('Edit People','Able to edit person objects','10ad4bc4-b6c1-11e0-bc9e-544249e32ba2'),('Edit Problems','Able to edit problems','879be458-6690-4a3a-84b1-1a19ff612dd7'),('Edit Relationships','Able to edit relationships','10ad4d90-b6c1-11e0-bc9e-544249e32ba2'),('Edit Report Objects','Able to edit report objects','10ad4f34-b6c1-11e0-bc9e-544249e32ba2'),('Edit Reports','Able to change information relating to a report design.','10ad50d8-b6c1-11e0-bc9e-544249e32ba2'),('Edit User Passwords','Able to change the passwords of users in OpenMRS','10ad527c-b6c1-11e0-bc9e-544249e32ba2'),('Edit Users','Able to change information relating to a user account.','10ad5420-b6c1-11e0-bc9e-544249e32ba2'),('Find Patient Shortcut','Show find-patient shortcut on homepage','10ad55ba-b6c1-11e0-bc9e-544249e32ba2'),('Form Entry','Access to the FormEntry application.','10ad5934-b6c1-11e0-bc9e-544249e32ba2'),('Manage Alerts','Able to add/edit/delete user alerts','10ad5ad8-b6c1-11e0-bc9e-544249e32ba2'),('Manage appointments','Able to add, edit, and delete patients\' appointment data','cf1a953e-b93d-11e0-a9ad-544249e49b14'),('Manage ART adherence','Able to add, edit, and delete ART adherence data','7233d36c-b93d-11e0-a9ad-544249e49b14'),('Manage ART visit','Able to add, edit, and delete ART visit data','4f8e9940-b934-11e0-a9ad-544249e49b14'),('Manage Concept Classes','Able to add, edit, and delete concept classes.','10ad5c68-b6c1-11e0-bc9e-544249e32ba2'),('Manage Concept Datatypes','Able to add, edit, and delete concept datatypes','10ad5e16-b6c1-11e0-bc9e-544249e32ba2'),('Manage Concept Name tags','Able to add/edit/delete concept name tags','b22ff50d-6d93-4d3e-937a-a932021c0d99'),('Manage Concept Sources','Able to add/edit/delete concept sources','10ad5fc4-b6c1-11e0-bc9e-544249e32ba2'),('Manage Concepts','Able to add/edit/delete concept entries','10ad617c-b6c1-11e0-bc9e-544249e32ba2'),('Manage drug dispensations','Able to add, edit, and delete - Give drugs data','92848740-b92b-11e0-a9ad-544249e49b14'),('Manage Encounter Types','Able to add, edit, and delete encounter types.','10ad632a-b6c1-11e0-bc9e-544249e32ba2'),('Manage Field Types','Able to add, edit, and delete field types.','10ad64e2-b6c1-11e0-bc9e-544249e32ba2'),('Manage Form Exports','Allows users to manage form exports','10ad667c-b6c1-11e0-bc9e-544249e32ba2'),('Manage FormEntry XSN','Allows user to upload and edit the xsns stored on the server','10ad6820-b6c1-11e0-bc9e-544249e32ba2'),('Manage Forms','Allows users to manage forms','10ad69d8-b6c1-11e0-bc9e-544249e32ba2'),('Manage Global Properties','Core Privilege','10ad6b7c-b6c1-11e0-bc9e-544249e32ba2'),('Manage Groups','Able to add, edit, and delete groups','10ad6d2a-b6c1-11e0-bc9e-544249e32ba2'),('Manage HIV first visits','Able to add, edit, and delete HIV first visit data','637115f4-b92b-11e0-a9ad-544249e49b14'),('Manage HIV reception visits','Able to add, edit, and delete HIV Reception data','e7d3c41e-b92a-11e0-a9ad-544249e49b14'),('Manage HIV staging visits','Able to add, edit, and delete HIV staging data','0a26fbe4-b92b-11e0-a9ad-544249e49b14'),('Manage Identifier Types','Able to add, edit, and delete identifier types.','10ad6ec4-b6c1-11e0-bc9e-544249e32ba2'),('Manage Implementation Id','Able to view/add/edit the implementation id for the system','991668dd-3aa9-48b5-8dcb-238a49cc8f5e'),('Manage Location Tags','Able to add/edit/delete location tags','a6eb2c95-8aab-4c58-a04d-d06b38403c2a'),('Manage Locations','Able to add, edit, and delete locations.','10ad707c-b6c1-11e0-bc9e-544249e32ba2'),('Manage Modules','Able to add/remove modules to the system','10ad7220-b6c1-11e0-bc9e-544249e32ba2'),('Manage Order Types','Able to add, edit, and delete order types.','10ad73ba-b6c1-11e0-bc9e-544249e32ba2'),('Manage Patient Programs','Core Privilege','10ad755e-b6c1-11e0-bc9e-544249e32ba2'),('Manage Person Attribute Types','Able to add/edit/delete person attribute tyeps','10ad772a-b6c1-11e0-bc9e-544249e32ba2'),('Manage pre ART visits','Able to add, edit, and delete Pre ART visit data','9c131156-b92a-11e0-a9ad-544249e49b14'),('Manage prescriptions','Able to add, edit, and delete prescriptions','e8ee1166-b93d-11e0-a9ad-544249e49b14'),('Manage Privileges','Able to add, edit, and delete user privileges.','10ad78e2-b6c1-11e0-bc9e-544249e32ba2'),('Manage Programs','Core Privilege','10ad7a7c-b6c1-11e0-bc9e-544249e32ba2'),('Manage Relationship Types','Core Privilege','10ad7c20-b6c1-11e0-bc9e-544249e32ba2'),('Manage Relationships','Core Privilege','10ad7dce-b6c1-11e0-bc9e-544249e32ba2'),('Manage Reports','Allows user to access all reporting use cases','10ad7f7c-b6c1-11e0-bc9e-544249e32ba2'),('Manage Roles','Able to add, edit, and delete user roles.','10ad8116-b6c1-11e0-bc9e-544249e32ba2'),('Manage Rule Definitions','Allows creation and editing of user-defined rules','13ca1165-54aa-4e11-9ba4-dc996216c19e'),('Manage Scheduler','Able to add/edit/remove scheduled tasks','10ad82b0-b6c1-11e0-bc9e-544249e32ba2'),('Manage TB reception visit','Able to add, edit, and delete TB Reception data','0a874fb6-b92c-11e0-a9ad-544249e49b14'),('Manage Tokens','Allows registering and removal of tokens','4c9ec3a5-6ae5-45ac-96d6-568a8dc6e7a8'),('Manage Vitals','Able to add, edit, and delete Vitals data','712d1d9c-b92a-11e0-a9ad-544249e49b14'),('Patient Dashboard - View Demographics Section','Core Privilege','10ad8472-b6c1-11e0-bc9e-544249e32ba2'),('Patient Dashboard - View Encounters Section','Core Privilege','10ad8634-b6c1-11e0-bc9e-544249e32ba2'),('Patient Dashboard - View Forms Section','Core Privilege','10ad880a-b6c1-11e0-bc9e-544249e32ba2'),('Patient Dashboard - View Graphs Section','Core Privilege','10ad8f58-b6c1-11e0-bc9e-544249e32ba2'),('Patient Dashboard - View Overview Section','Core Privilege','10ad9156-b6c1-11e0-bc9e-544249e32ba2'),('Patient Dashboard - View Patient Summary','Able to view the \'Summary\' tab on the patient dashboard','10ad934a-b6c1-11e0-bc9e-544249e32ba2'),('Patient Dashboard - View Regimen Section','Core Privilege','10ad9516-b6c1-11e0-bc9e-544249e32ba2'),('Purge Field Types','Able to purge field types','10ad96e2-b6c1-11e0-bc9e-544249e32ba2'),('Remove Allergies','Remove allergies','b43d0b09-38a5-4734-a230-3349465e571d'),('Remove Problems','Remove problems','7169d60c-c7a1-420b-8558-a20b5df2f47a'),('Run Reports','Able to run reports','0867ee5f-65c9-4f2f-856a-ed33a9309401'),('Upload XSN','Allows user to upload/overwrite the XSNs defined for forms','10ad987c-b6c1-11e0-bc9e-544249e32ba2'),('View Administration Functions','Core Privilege','10ad99f8-b6c1-11e0-bc9e-544249e32ba2'),('View Allergies','Able to view allergies','5954b062-4f87-470f-b654-f7730c4bdccf'),('View Concept Classes','Able to view concept classes','10ad9b9c-b6c1-11e0-bc9e-544249e32ba2'),('View Concept Datatypes','Able to view concept datatypes','10ad9d40-b6c1-11e0-bc9e-544249e32ba2'),('View Concept Proposals','Able to view concept proposals to the system','10ad9eee-b6c1-11e0-bc9e-544249e32ba2'),('View Concept Sources','Able to view concept sources','10ada0a6-b6c1-11e0-bc9e-544249e32ba2'),('View Concepts','Able to browse the concept dictionary.','10ada240-b6c1-11e0-bc9e-544249e32ba2'),('View Data Entry Statistics','Able to view data entry statistics from the admin screen','10ada3e4-b6c1-11e0-bc9e-544249e32ba2'),('View Database Changes','Able to view database changes from the admin screen','9d14e0cd-ebdb-41be-a2c7-57ce84089b0a'),('View Encounter Types','Able to view encounter types','10ada588-b6c1-11e0-bc9e-544249e32ba2'),('View Encounters','Able to view metadata relating to clinical encounters','10ada72c-b6c1-11e0-bc9e-544249e32ba2'),('View Field Types','Able to view field types','10ada8c6-b6c1-11e0-bc9e-544249e32ba2'),('View FormEntry Archive','Allows the user to view the formentry archive','10adaa60-b6c1-11e0-bc9e-544249e32ba2'),('View FormEntry Error','Allows a user to view a formentry error','10adac18-b6c1-11e0-bc9e-544249e32ba2'),('View FormEntry Queue','Allows user to view the queue items','10adadbc-b6c1-11e0-bc9e-544249e32ba2'),('View Forms','Able to view forms.','10adaf60-b6c1-11e0-bc9e-544249e32ba2'),('View Global Properties','Able to view global properties on the administration screen','10adb0fa-b6c1-11e0-bc9e-544249e32ba2'),('View Identifier Types','Able to view patient identifier types','10adb29e-b6c1-11e0-bc9e-544249e32ba2'),('View Locations','Able to view locations','10adb442-b6c1-11e0-bc9e-544249e32ba2'),('View Navigation Menu','Core Privilege','10adbb2c-b6c1-11e0-bc9e-544249e32ba2'),('View Observations','Able to view preexisting information/notes relating to observations.','10adbce4-b6c1-11e0-bc9e-544249e32ba2'),('View Order Types','Able to view order types','10adbe88-b6c1-11e0-bc9e-544249e32ba2'),('View Orders','Able to view information about orders.','10adc02c-b6c1-11e0-bc9e-544249e32ba2'),('View Patient Cohorts','Able to view patient cohorts','10adc1bc-b6c1-11e0-bc9e-544249e32ba2'),('View Patient Identifiers','Able to view patient identifiers','10adc630-b6c1-11e0-bc9e-544249e32ba2'),('View Patient Programs','Able to see which programs that patients are in','10adc810-b6c1-11e0-bc9e-544249e32ba2'),('View Patient Sets','Core Privilege','10adc9dc-b6c1-11e0-bc9e-544249e32ba2'),('View Patients','Able to view attributes of a patient','10adcba8-b6c1-11e0-bc9e-544249e32ba2'),('View People','Able to view person objects','10adcd6a-b6c1-11e0-bc9e-544249e32ba2'),('View Person Attribute Types','Able to view person attribute types','10adcf2c-b6c1-11e0-bc9e-544249e32ba2'),('View Privileges','Able to view user privileges','10add0f8-b6c1-11e0-bc9e-544249e32ba2'),('View Problems','Able to view problems','5943e563-13fc-44a8-a22d-24c09bff0836'),('View Programs','Core Privilege','10add2b0-b6c1-11e0-bc9e-544249e32ba2'),('View Relationship Types','Able to view relationship types','10add468-b6c1-11e0-bc9e-544249e32ba2'),('View Relationships','Able to view relationships','10add634-b6c1-11e0-bc9e-544249e32ba2'),('View Report Objects','Able to view report objects','10add80a-b6c1-11e0-bc9e-544249e32ba2'),('View Reports','Able to review information about a particular report design.','10ade3d6-b6c1-11e0-bc9e-544249e32ba2'),('View Roles','Able to view user roles','10ade5ac-b6c1-11e0-bc9e-544249e32ba2'),('View Rule Definitions','Allows viewing of user-defined rules. (This privilege is not necessary to run rules under normal usage.)','775486fe-aa30-46f9-80bb-d4ea8712a933'),('View Unpublished Forms','Core Privilege','10ade75a-b6c1-11e0-bc9e-544249e32ba2'),('View Users','Able to browse user lists and metainformation about a user.','10ade930-b6c1-11e0-bc9e-544249e32ba2');
/*!40000 ALTER TABLE `privilege` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2011-07-28 19:58:47