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
-- Table structure for table `departments`
--

DROP TABLE IF EXISTS `departments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `departments` (
  `department_id` int NOT NULL AUTO_INCREMENT,
  `organization_id` int NOT NULL,
  `department_name` varchar(100) NOT NULL,
  `description` text,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `priority_high_hours` int DEFAULT '24',
  `priority_medium_hours` int DEFAULT '72',
  `priority_low_hours` int DEFAULT '168',
  PRIMARY KEY (`department_id`),
  KEY `organization_id` (`organization_id`),
  CONSTRAINT `departments_ibfk_1` FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`organization_id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `departments`
--

LOCK TABLES `departments` WRITE;
/*!40000 ALTER TABLE `departments` DISABLE KEYS */;
INSERT INTO `departments` VALUES (1,1,'Housekeeping','Cleaning and sanitation','2026-06-30 08:56:28',24,72,168),(2,1,'Electrical','Electrical maintenance','2026-06-30 08:56:28',24,72,168),(3,1,'Infrastructure','Building maintenance','2026-06-30 08:56:28',24,72,168),(4,1,'Network Connectivity','Internet and networking','2026-06-30 08:56:28',24,72,168),(5,1,'Hostel','Hostel related issues','2026-06-30 08:56:28',24,72,168),(6,1,'Parking & Transportation','Parking and bus services','2026-06-30 08:56:28',24,72,168),(7,1,'Security','Campus security','2026-06-30 08:56:28',24,72,168),(8,1,'Canteen','Food services','2026-06-30 08:56:28',24,72,168),(9,1,'Others','Miscellaneous issues','2026-06-30 08:56:28',24,72,168);
/*!40000 ALTER TABLE `departments` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-07-04 14:33:19
