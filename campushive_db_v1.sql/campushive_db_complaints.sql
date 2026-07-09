-- MySQL dump 10.13  Distrib 8.0.46, for Win64 (x86_64)
--
-- Host: localhost    Database: campushive_db
-- ------------------------------------------------------
-- Server version	8.0.46

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `complaints`
--

DROP TABLE IF EXISTS `complaints`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `complaints` (
  `complaint_id` int NOT NULL AUTO_INCREMENT,
  `organization_id` int NOT NULL,
  `student_id` int NOT NULL,
  `supervisor_id` int DEFAULT NULL,
  `department_id` int NOT NULL,
  `title` varchar(200) NOT NULL,
  `description` text NOT NULL,
  `location` varchar(255) DEFAULT NULL,
  `ml_priority` enum('LOW','MEDIUM','HIGH') DEFAULT NULL,
  `final_priority` enum('LOW','MEDIUM','HIGH') DEFAULT NULL,
  `status` enum('PENDING','ASSIGNED','IN_PROGRESS','RESOLVED','REOPENED','ESCALATED','CLOSED') DEFAULT 'PENDING',
  `support_count` int DEFAULT '0',
  `deadline` datetime DEFAULT NULL,
  `resolved_at` datetime DEFAULT NULL,
  `student_feedback` enum('SATISFIED','NOT_SATISFIED') DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`complaint_id`),
  KEY `organization_id` (`organization_id`),
  KEY `student_id` (`student_id`),
  KEY `supervisor_id` (`supervisor_id`),
  KEY `department_id` (`department_id`),
  CONSTRAINT `complaints_ibfk_1` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`organization_id`),
  CONSTRAINT `complaints_ibfk_2` FOREIGN KEY (`student_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `complaints_ibfk_3` FOREIGN KEY (`supervisor_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `complaints_ibfk_4` FOREIGN KEY (`department_id`) REFERENCES `departments` (`department_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `complaints`
--

LOCK TABLES `complaints` WRITE;
/*!40000 ALTER TABLE `complaints` DISABLE KEYS */;
/*!40000 ALTER TABLE `complaints` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-07-04 14:33:18
