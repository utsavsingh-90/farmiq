
DROP DATABASE IF EXISTS crop_recommendation_db;
CREATE DATABASE crop_recommendation_db
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE crop_recommendation_db;

-- =========================
-- REGION
-- =========================
CREATE TABLE Region (
  region_id   INT AUTO_INCREMENT PRIMARY KEY,
  region_name VARCHAR(100) UNIQUE NOT NULL
) ENGINE=InnoDB;

-- =========================
-- FARMER
-- =========================
CREATE TABLE Farmer (
  farmer_id      INT AUTO_INCREMENT PRIMARY KEY,
  name           VARCHAR(100) NOT NULL,
  contact_number VARCHAR(15)  UNIQUE NOT NULL,
  location       VARCHAR(150) NOT NULL,
  farm_size      DECIMAL(10,2) NOT NULL,
  region_id      INT NULL,
  CONSTRAINT chk_farm_size CHECK (farm_size > 0),
  CONSTRAINT fk_farmer_region FOREIGN KEY (region_id) REFERENCES Region(region_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================
-- LAND PARCEL
-- =========================
CREATE TABLE Land_Parcel (
  land_id        INT AUTO_INCREMENT PRIMARY KEY,
  latitude       DECIMAL(9,6) NOT NULL,
  longitude      DECIMAL(9,6) NOT NULL,
  area           DECIMAL(10,2) NOT NULL,
  irrigation_type ENUM('Drip','Sprinkler','Flood','Rainfed','Canal') NOT NULL,
  farmer_id      INT NOT NULL,
  region_id      INT NOT NULL,
  CONSTRAINT chk_area CHECK (area > 0),
  CONSTRAINT fk_land_farmer FOREIGN KEY (farmer_id) REFERENCES Farmer(farmer_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_land_region FOREIGN KEY (region_id) REFERENCES Region(region_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_land_farmer ON Land_Parcel(farmer_id);
CREATE INDEX idx_land_region ON Land_Parcel(region_id);

-- =========================
-- CLIMATE DATA
-- =========================
CREATE TABLE Climate_Data (
  climate_id      INT AUTO_INCREMENT PRIMARY KEY,
  avg_temperature DECIMAL(5,2) NOT NULL,
  rainfall        DECIMAL(7,2) NOT NULL,
  humidity        DECIMAL(5,2) NOT NULL,
  season          ENUM('Kharif','Rabi','Zaid','Year-Round') NOT NULL,
  year            YEAR NOT NULL,
  region_id       INT NOT NULL,
  CONSTRAINT chk_rainfall  CHECK (rainfall >= 0),
  CONSTRAINT chk_humidity  CHECK (humidity BETWEEN 0 AND 100),
  CONSTRAINT fk_climate_region FOREIGN KEY (region_id) REFERENCES Region(region_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_climate_region ON Climate_Data(region_id);

-- =========================
-- SOIL TEST  (Composite PK — weak entity)
-- =========================
CREATE TABLE Soil_Test (
  land_id          INT  NOT NULL,
  test_date        DATE NOT NULL,
  nitrogen_level   DECIMAL(7,2) NOT NULL,
  phosphorus_level DECIMAL(7,2) NOT NULL,
  potassium_level  DECIMAL(7,2) NOT NULL,
  pH               DECIMAL(4,2) NOT NULL,
  organic_matter   DECIMAL(5,2) NOT NULL,
  PRIMARY KEY (land_id, test_date),
  CONSTRAINT fk_soil_land FOREIGN KEY (land_id) REFERENCES Land_Parcel(land_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_nitrogen_s   CHECK (nitrogen_level   >= 0),
  CONSTRAINT chk_phosphorus_s CHECK (phosphorus_level >= 0),
  CONSTRAINT chk_potassium_s  CHECK (potassium_level  >= 0),
  CONSTRAINT chk_ph_s         CHECK (pH BETWEEN 0 AND 14),
  CONSTRAINT chk_om_s         CHECK (organic_matter   >= 0)
) ENGINE=InnoDB;

-- =========================
-- CROP
-- =========================
CREATE TABLE Crop (
  crop_id          INT AUTO_INCREMENT PRIMARY KEY,
  crop_name        VARCHAR(100) UNIQUE NOT NULL,
  crop_type        ENUM('Cereal','Pulse','Oilseed','Vegetable','Fruit','Spice','Fiber','Commercial') NOT NULL,
  growth_duration  INT NOT NULL,
  water_requirement DECIMAL(8,2) NOT NULL,
  carbon_footprint DECIMAL(8,2) NOT NULL,
  avg_market_price DECIMAL(10,2) NOT NULL,
  CONSTRAINT chk_duration      CHECK (growth_duration  > 0),
  CONSTRAINT chk_water_req     CHECK (water_requirement >= 0),
  CONSTRAINT chk_carbon        CHECK (carbon_footprint  >= 0),
  CONSTRAINT chk_market_price  CHECK (avg_market_price  > 0)
) ENGINE=InnoDB;

-- =========================
-- CROP REQUIREMENT
-- FIX: Numeric ranges instead of VARCHAR strings
-- This enables actual SQL queries like:
--   WHERE st.pH BETWEEN cr.min_ph AND cr.max_ph
-- =========================
CREATE TABLE Crop_Requirement (
  requirement_id INT AUTO_INCREMENT PRIMARY KEY,
  crop_id        INT UNIQUE NOT NULL,
  min_nitrogen   DECIMAL(7,2) NOT NULL,
  max_nitrogen   DECIMAL(7,2) NOT NULL,
  min_ph         DECIMAL(4,2) NOT NULL,
  max_ph         DECIMAL(4,2) NOT NULL,
  min_temp       DECIMAL(5,2) NOT NULL,   -- °C
  max_temp       DECIMAL(5,2) NOT NULL,   -- °C
  min_rainfall   DECIMAL(7,2) NOT NULL,   -- mm/year
  max_rainfall   DECIMAL(7,2) NOT NULL,   -- mm/year
  CONSTRAINT fk_crop_req FOREIGN KEY (crop_id) REFERENCES Crop(crop_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_nitrogen_range  CHECK (max_nitrogen >= min_nitrogen AND min_nitrogen >= 0),
  CONSTRAINT chk_ph_range        CHECK (max_ph >= min_ph AND min_ph BETWEEN 0 AND 14 AND max_ph BETWEEN 0 AND 14),
  CONSTRAINT chk_temp_range      CHECK (max_temp >= min_temp),
  CONSTRAINT chk_rainfall_range  CHECK (max_rainfall >= min_rainfall AND min_rainfall >= 0)
) ENGINE=InnoDB;

-- =========================
-- SUSTAINABILITY INDEX
-- =========================
CREATE TABLE Sustainability_Index (
  sustainability_id       INT AUTO_INCREMENT PRIMARY KEY,
  land_id                 INT NOT NULL,
  soil_health_score       DECIMAL(5,2) NOT NULL,
  water_availability_score DECIMAL(5,2) NOT NULL,
  carbon_emission_score   DECIMAL(5,2) NOT NULL,
  biodiversity_score      DECIMAL(5,2) NOT NULL,
  calculated_date         DATE NOT NULL,
  CONSTRAINT fk_sust_land FOREIGN KEY (land_id) REFERENCES Land_Parcel(land_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_soil_score    CHECK (soil_health_score        BETWEEN 0 AND 100),
  CONSTRAINT chk_water_score   CHECK (water_availability_score BETWEEN 0 AND 100),
  CONSTRAINT chk_carbon_score  CHECK (carbon_emission_score    BETWEEN 0 AND 100),
  CONSTRAINT chk_bio_score     CHECK (biodiversity_score       BETWEEN 0 AND 100)
) ENGINE=InnoDB;

CREATE INDEX idx_sust_land ON Sustainability_Index(land_id);

-- =========================
-- RECOMMENDATION
-- =========================
CREATE TABLE Recommendation (
  recommendation_id  INT AUTO_INCREMENT PRIMARY KEY,
  land_id            INT NOT NULL,
  crop_id            INT NOT NULL,
  predicted_yield    DECIMAL(10,2) NOT NULL,
  expected_profit    DECIMAL(12,2),           -- computed by trigger
  sustainability_score DECIMAL(5,2) NOT NULL,
  recommendation_date DATE NOT NULL DEFAULT (CURRENT_DATE),
  CONSTRAINT fk_rec_land FOREIGN KEY (land_id) REFERENCES Land_Parcel(land_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_rec_crop FOREIGN KEY (crop_id) REFERENCES Crop(crop_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_yield         CHECK (predicted_yield    >= 0),
  CONSTRAINT chk_sust_score_r  CHECK (sustainability_score BETWEEN 0 AND 100)
) ENGINE=InnoDB;

CREATE INDEX idx_rec_land ON Recommendation(land_id);
CREATE INDEX idx_rec_crop ON Recommendation(crop_id);

-- =============================================================
-- TRIGGER: Auto-calculate expected_profit using real market price
-- FIX: Script 2 hardcoded × 20000; this joins Crop for actual price
-- Formula: yield (tons) × 10 quintals/ton × avg_market_price (₹/quintal)
-- =============================================================
DELIMITER //

CREATE TRIGGER trg_auto_profit
BEFORE INSERT ON Recommendation
FOR EACH ROW
BEGIN
  DECLARE v_price DECIMAL(10,2);
  SELECT avg_market_price INTO v_price FROM Crop WHERE crop_id = NEW.crop_id;
  -- predicted_yield in tons/acre × 10 quintals/ton × market price per quintal
  SET NEW.expected_profit = NEW.predicted_yield * 10 * v_price;
END //

DELIMITER ;

-- =============================================================
-- VIEW: High Sustainability Recommendations (score > 80)
-- =============================================================
CREATE VIEW High_Sustainability AS
SELECT
  r.recommendation_id,
  f.name          AS farmer_name,
  rg.region_name,
  c.crop_name,
  c.crop_type,
  r.predicted_yield,
  r.expected_profit,
  r.sustainability_score,
  r.recommendation_date
FROM Recommendation r
JOIN Land_Parcel lp ON r.land_id = lp.land_id
JOIN Farmer f       ON lp.farmer_id = f.farmer_id
JOIN Region rg      ON lp.region_id = rg.region_id
JOIN Crop c         ON r.crop_id = c.crop_id
WHERE r.sustainability_score > 80;

-- =============================================================
-- VIEW: Crop Suitability Match (soil vs crop requirements)
-- Farmers/admins can query this to see which crops suit a land
-- =============================================================
CREATE VIEW Crop_Soil_Match AS
SELECT
  lp.land_id,
  f.name           AS farmer_name,
  rg.region_name,
  st.test_date,
  c.crop_name,
  c.crop_type,
  c.avg_market_price,
  st.pH,
  st.nitrogen_level,
  cr.min_ph, cr.max_ph,
  cr.min_nitrogen, cr.max_nitrogen,
  CASE
    WHEN st.pH BETWEEN cr.min_ph AND cr.max_ph
     AND st.nitrogen_level BETWEEN cr.min_nitrogen AND cr.max_nitrogen
    THEN 'SUITABLE'
    WHEN st.pH BETWEEN cr.min_ph - 0.5 AND cr.max_ph + 0.5
    THEN 'MARGINAL'
    ELSE 'NOT SUITABLE'
  END AS suitability
FROM Soil_Test st
JOIN Land_Parcel lp  ON st.land_id = lp.land_id
JOIN Farmer f        ON lp.farmer_id = f.farmer_id
JOIN Region rg       ON lp.region_id = rg.region_id
CROSS JOIN Crop c
JOIN Crop_Requirement cr ON c.crop_id = cr.crop_id;

-- =============================================================
-- STORED PROCEDURE: Get best crop for a land parcel
-- =============================================================
DELIMITER //

CREATE PROCEDURE GetBestCrop(IN p_land_id INT)
BEGIN
  SELECT
    c.crop_name,
    c.crop_type,
    r.predicted_yield,
    r.expected_profit,
    r.sustainability_score,
    r.recommendation_date
  FROM Recommendation r
  JOIN Crop c ON r.crop_id = c.crop_id
  WHERE r.land_id = p_land_id
  ORDER BY r.sustainability_score DESC, r.expected_profit DESC
  LIMIT 1;
END //

-- =============================================================
-- STORED PROCEDURE: Get all suitable crops for a land (from soil)
-- =============================================================
CREATE PROCEDURE GetSuitableCrops(IN p_land_id INT)
BEGIN
  SELECT
    c.crop_name,
    c.crop_type,
    c.avg_market_price,
    c.growth_duration,
    c.water_requirement,
    cr.min_ph, cr.max_ph,
    cr.min_temp, cr.max_temp,
    cr.min_rainfall, cr.max_rainfall,
    st.pH AS soil_ph,
    st.nitrogen_level
  FROM Crop c
  JOIN Crop_Requirement cr ON c.crop_id = cr.crop_id
  JOIN (
    SELECT * FROM Soil_Test
    WHERE land_id = p_land_id
    ORDER BY test_date DESC LIMIT 1
  ) st ON TRUE
  WHERE st.pH BETWEEN cr.min_ph AND cr.max_ph
    AND st.nitrogen_level BETWEEN cr.min_nitrogen AND cr.max_nitrogen
  ORDER BY c.avg_market_price DESC;
END //

DELIMITER ;

-- =============================================================
-- SEED DATA
-- =============================================================

-- Regions (25 Indian states)
INSERT INTO Region (region_name) VALUES
('Punjab'),('Haryana'),('Uttar Pradesh'),('Madhya Pradesh'),('Rajasthan'),
('Gujarat'),('Maharashtra'),('Karnataka'),('Andhra Pradesh'),('Tamil Nadu'),
('West Bengal'),('Bihar'),('Jharkhand'),('Odisha'),('Chhattisgarh'),
('Telangana'),('Kerala'),('Himachal Pradesh'),('Uttarakhand'),('Assam'),
('Manipur'),('Tripura'),('Meghalaya'),('Sikkim'),('Goa');

-- Farmers (25) — region_id backfilled from Land_Parcel assignments
INSERT INTO Farmer (name, contact_number, location, farm_size, region_id) VALUES
('Rajinder Singh','9876543210','Amritsar, Punjab',12.50,1),
('Harpreet Kaur','9876543211','Ludhiana, Punjab',8.75,1),
('Mahesh Verma','9876543212','Agra, Uttar Pradesh',15.00,3),
('Sunita Devi','9876543213','Varanasi, Uttar Pradesh',6.25,3),
('Ramesh Patel','9876543214','Ahmedabad, Gujarat',20.00,6),
('Kavita Sharma','9876543215','Jaipur, Rajasthan',9.50,5),
('Suresh Yadav','9876543216','Patna, Bihar',7.00,12),
('Anjali Mishra','9876543217','Bhopal, Madhya Pradesh',18.00,4),
('Pradeep Kumar','9876543218','Nagpur, Maharashtra',11.25,7),
('Lakshmi Reddy','9876543219','Hyderabad, Telangana',14.00,16),
('Venkatesh Rao','9876543220','Bangalore, Karnataka',5.50,8),
('Meena Pillai','9876543221','Coimbatore, Tamil Nadu',10.00,10),
('Arun Das','9876543222','Kolkata, West Bengal',3.75,11),
('Poonam Gupta','9876543223','Lucknow, Uttar Pradesh',8.00,3),
('Deepak Joshi','9876543224','Dehradun, Uttarakhand',13.50,19),
('Sanjay Tiwari','9876543225','Raipur, Chhattisgarh',16.00,15),
('Rekha Nair','9876543226','Thiruvananthapuram, Kerala',4.25,17),
('Mohan Lal','9876543227','Shimla, Himachal Pradesh',22.00,18),
('Geeta Bose','9876543228','Guwahati, Assam',9.00,20),
('Rajesh Agarwal','9876543229','Indore, Madhya Pradesh',17.50,4),
('Fatima Khan','9876543230','Aurangabad, Maharashtra',11.00,7),
('Santosh Pal','9876543231','Cuttack, Odisha',6.50,14),
('Vijay Sharma','9876543232','Jodhpur, Rajasthan',25.00,5),
('Asha Rani','9876543233','Ranchi, Jharkhand',8.25,13),
('Naresh Chandra','9876543234','Panaji, Goa',3.00,25);

-- Land Parcels (25)
INSERT INTO Land_Parcel (latitude, longitude, area, irrigation_type, farmer_id, region_id) VALUES
(31.633600,74.872300,5.00,'Canal',1,1),(30.900900,75.857300,3.75,'Drip',2,1),
(27.176700,78.008100,8.00,'Flood',3,3),(25.317600,82.973500,4.50,'Canal',4,3),
(23.022500,72.571400,6.00,'Drip',5,6),(26.912400,75.787300,5.50,'Sprinkler',6,5),
(25.594100,85.137600,3.00,'Rainfed',7,12),(23.259900,77.412800,7.25,'Canal',8,4),
(21.145800,79.088100,4.00,'Drip',9,7),(17.385000,78.486700,6.50,'Sprinkler',10,16),
(12.971600,77.594600,2.50,'Drip',11,8),(11.004100,76.961700,5.00,'Drip',12,10),
(22.572600,88.363900,2.00,'Flood',13,11),(26.846700,80.946200,4.25,'Canal',14,3),
(30.316500,78.032200,6.00,'Rainfed',15,19),(21.251400,81.629400,8.50,'Rainfed',16,15),
(8.524139,76.936638,2.50,'Rainfed',17,17),(31.104800,77.172500,10.00,'Sprinkler',18,18),
(26.144500,91.736200,4.00,'Rainfed',19,20),(22.719600,75.857300,9.00,'Canal',20,4),
(19.876200,75.343800,5.50,'Drip',21,7),(20.462500,85.882800,3.25,'Rainfed',22,14),
(26.293600,73.016400,12.00,'Sprinkler',23,5),(23.343200,85.309600,4.25,'Rainfed',24,13),
(15.499200,73.823800,1.50,'Drip',25,25);

-- Climate Data (25)
INSERT INTO Climate_Data (avg_temperature, rainfall, humidity, season, year, region_id) VALUES
(28.50,850.00,72.00,'Kharif',2023,1),(25.00,620.00,65.00,'Rabi',2023,2),
(32.00,900.00,70.00,'Kharif',2023,3),(30.00,750.00,68.00,'Rabi',2023,4),
(35.00,450.00,45.00,'Rabi',2023,5),(33.00,700.00,60.00,'Kharif',2023,6),
(29.00,1100.00,80.00,'Kharif',2023,7),(26.00,950.00,75.00,'Kharif',2023,8),
(31.00,870.00,72.00,'Kharif',2023,9),(34.00,820.00,65.00,'Kharif',2023,10),
(27.00,1500.00,85.00,'Year-Round',2023,11),(29.50,980.00,78.00,'Kharif',2023,12),
(28.00,820.00,70.00,'Kharif',2023,13),(30.50,1200.00,82.00,'Kharif',2023,14),
(31.00,1050.00,76.00,'Kharif',2023,15),(32.50,780.00,68.00,'Kharif',2023,16),
(27.50,2800.00,90.00,'Year-Round',2023,17),(22.00,600.00,60.00,'Rabi',2023,18),
(24.00,1400.00,78.00,'Kharif',2023,19),(28.00,1700.00,85.00,'Kharif',2023,20),
(26.50,1350.00,82.00,'Kharif',2023,21),(27.00,1900.00,88.00,'Kharif',2023,22),
(23.50,2200.00,87.00,'Kharif',2023,23),(21.00,2500.00,88.00,'Kharif',2023,24),
(29.00,3000.00,85.00,'Year-Round',2023,25);

-- Crops (25)
INSERT INTO Crop (crop_name, crop_type, growth_duration, water_requirement, carbon_footprint, avg_market_price) VALUES
('Rice','Cereal',120,1200.00,2.70,1950.00),
('Wheat','Cereal',150,450.00,0.65,2015.00),
('Maize','Cereal',90,500.00,0.90,1700.00),
('Soybean','Oilseed',100,450.00,0.55,4200.00),
('Groundnut','Oilseed',120,500.00,0.60,5100.00),
('Sugarcane','Commercial',365,1800.00,3.20,310.00),
('Cotton','Fiber',180,700.00,1.80,6500.00),
('Chickpea','Pulse',130,350.00,0.45,5200.00),
('Lentil','Pulse',120,300.00,0.40,5500.00),
('Mustard','Oilseed',110,300.00,0.50,5000.00),
('Potato','Vegetable',90,600.00,0.85,1200.00),
('Tomato','Vegetable',80,650.00,0.95,1500.00),
('Onion','Vegetable',100,500.00,0.70,1800.00),
('Banana','Fruit',365,900.00,0.80,2000.00),
('Mango','Fruit',1825,700.00,0.75,4000.00),
('Turmeric','Spice',270,1100.00,1.20,7000.00),
('Ginger','Spice',240,1200.00,1.30,9000.00),
('Jute','Fiber',150,1000.00,1.10,350.00),
('Sunflower','Oilseed',90,350.00,0.50,4800.00),
('Barley','Cereal',110,400.00,0.55,1600.00),
('Sorghum','Cereal',100,300.00,0.60,1500.00),
('Pearl Millet','Cereal',90,250.00,0.50,1450.00),
('Pigeonpea','Pulse',180,400.00,0.45,6000.00),
('Green Gram','Pulse',65,300.00,0.35,7500.00),
('Coconut','Fruit',2555,1500.00,0.50,1800.00);

-- Crop Requirements (25) — FIX: numeric min/max instead of VARCHAR strings
-- Columns: crop_id, min_n, max_n, min_ph, max_ph, min_temp, max_temp, min_rain, max_rain
INSERT INTO Crop_Requirement
  (crop_id, min_nitrogen, max_nitrogen, min_ph, max_ph, min_temp, max_temp, min_rainfall, max_rainfall)
VALUES
(1,  100, 160, 5.5, 7.0, 22, 35, 1000, 2000),
(2,   80, 130, 6.0, 7.5, 15, 25,  400,  600),
(3,   80, 120, 5.8, 7.0, 21, 32,  400,  700),
(4,   60, 100, 6.0, 7.0, 20, 30,  400,  600),
(5,   80, 120, 6.0, 7.0, 25, 35,  500, 1000),
(6,  150, 250, 6.0, 7.5, 20, 35, 1500, 2500),
(7,  100, 180, 5.8, 7.0, 25, 35,  700, 1200),
(8,   40,  80, 6.0, 8.0, 20, 30,  300,  450),
(9,   40,  80, 5.8, 7.5, 18, 28,  250,  400),
(10,  60, 100, 6.0, 7.5, 15, 25,  250,  500),
(11, 120, 180, 5.5, 7.0, 15, 25,  500,  700),
(12, 100, 160, 6.0, 7.0, 20, 28,  600,  800),
(13,  80, 130, 6.0, 7.5, 13, 25,  500,  700),
(14,  80, 140, 5.5, 7.0, 25, 35,  750, 1200),
(15,  60, 120, 5.5, 7.5, 24, 35,  750, 2000),
(16, 100, 180, 5.5, 7.0, 25, 35, 1000, 2000),
(17, 100, 180, 5.5, 6.5, 22, 32, 1000, 1500),
(18,  60, 100, 6.0, 7.0, 25, 35, 1000, 2000),
(19,  60, 100, 6.0, 7.5, 22, 32,  300,  500),
(20,  60, 100, 6.0, 7.5, 12, 22,  300,  500),
(21,  40,  80, 6.0, 8.0, 26, 36,  400,  600),
(22,  40,  80, 6.0, 8.0, 28, 40,  200,  400),
(23,  60, 100, 6.0, 7.5, 25, 35,  600, 1000),
(24,  40,  80, 6.0, 7.5, 30, 40,  300,  400),
(25,  60, 120, 5.5, 8.0, 25, 35, 1500, 2500);

-- Soil Tests (25)
INSERT INTO Soil_Test (land_id, test_date, nitrogen_level, phosphorus_level, potassium_level, pH, organic_matter) VALUES
(1,'2023-06-01',120,45,80,6.50,2.50),(2,'2023-06-05',95,38,70,6.80,2.10),
(3,'2023-06-10',140,55,90,7.00,3.00),(4,'2023-06-12',85,30,65,7.20,1.80),
(5,'2023-06-15',160,60,100,6.30,3.50),(6,'2023-06-18',75,25,55,8.00,1.20),
(7,'2023-06-20',100,42,75,6.70,2.20),(8,'2023-06-22',130,50,85,6.90,2.80),
(9,'2023-06-25',115,48,78,7.10,2.40),(10,'2023-06-28',145,58,95,6.40,3.20),
(11,'2023-07-01',90,35,68,6.60,2.00),(12,'2023-07-03',110,44,76,6.80,2.60),
(13,'2023-07-05',80,28,58,5.80,1.50),(14,'2023-07-08',125,52,88,7.00,2.90),
(15,'2023-07-10',105,40,72,6.20,2.30),(16,'2023-07-12',135,54,92,6.50,3.10),
(17,'2023-07-15',70,22,50,5.50,1.80),(18,'2023-07-18',150,62,102,6.00,3.80),
(19,'2023-07-20',88,32,62,6.70,1.90),(20,'2023-07-22',118,47,82,7.00,2.70),
(21,'2023-07-25',128,51,87,6.80,2.60),(22,'2023-07-28',92,36,66,5.90,2.00),
(23,'2023-08-01',72,24,52,8.20,1.00),(24,'2023-08-03',108,43,74,6.30,2.40),
(25,'2023-08-05',155,65,108,6.10,4.00);

-- Sustainability Index (25)
INSERT INTO Sustainability_Index
  (land_id, soil_health_score, water_availability_score, carbon_emission_score, biodiversity_score, calculated_date)
VALUES
(1,78.50,82.00,65.00,70.00,'2023-07-01'),(2,72.00,75.00,70.00,68.00,'2023-07-01'),
(3,85.00,88.00,55.00,80.00,'2023-07-02'),(4,65.00,60.00,75.00,62.00,'2023-07-02'),
(5,90.00,85.00,50.00,88.00,'2023-07-03'),(6,55.00,45.00,85.00,50.00,'2023-07-03'),
(7,68.00,70.00,72.00,65.00,'2023-07-04'),(8,80.00,78.00,60.00,75.00,'2023-07-04'),
(9,75.00,80.00,62.00,72.00,'2023-07-05'),(10,82.00,84.00,58.00,78.00,'2023-07-05'),
(11,70.00,72.00,68.00,66.00,'2023-07-06'),(12,76.00,79.00,63.00,74.00,'2023-07-06'),
(13,62.00,55.00,80.00,58.00,'2023-07-07'),(14,84.00,86.00,54.00,82.00,'2023-07-07'),
(15,71.00,73.00,67.00,69.00,'2023-07-08'),(16,88.00,90.00,48.00,85.00,'2023-07-08'),
(17,58.00,50.00,88.00,54.00,'2023-07-09'),(18,92.00,93.00,42.00,90.00,'2023-07-09'),
(19,64.00,62.00,78.00,60.00,'2023-07-10'),(20,79.00,81.00,61.00,76.00,'2023-07-10'),
(21,83.00,85.00,56.00,79.00,'2023-07-11'),(22,67.00,69.00,73.00,64.00,'2023-07-11'),
(23,52.00,42.00,90.00,48.00,'2023-07-12'),(24,74.00,76.00,65.00,71.00,'2023-07-12'),
(25,95.00,97.00,38.00,93.00,'2023-07-13');

-- Recommendations (25) — expected_profit auto-calculated by trigger
INSERT INTO Recommendation (land_id, crop_id, predicted_yield, sustainability_score, recommendation_date) VALUES
(1,1,5.20,78.00,'2023-07-15'),(2,2,4.80,72.00,'2023-07-15'),
(3,3,7.50,85.00,'2023-07-16'),(4,8,3.80,65.00,'2023-07-16'),
(5,4,6.00,90.00,'2023-07-17'),(6,6,4.50,55.00,'2023-07-17'),
(7,1,3.20,68.00,'2023-07-18'),(8,7,7.80,80.00,'2023-07-18'),
(9,3,4.20,75.00,'2023-07-19'),(10,5,6.50,82.00,'2023-07-19'),
(11,11,3.60,70.00,'2023-07-20'),(12,12,4.90,76.00,'2023-07-20'),
(13,18,2.80,62.00,'2023-07-21'),(14,1,5.50,84.00,'2023-07-21'),
(15,20,4.00,71.00,'2023-07-22'),(16,10,8.20,88.00,'2023-07-22'),
(17,14,2.50,58.00,'2023-07-23'),(18,2,9.50,92.00,'2023-07-23'),
(19,1,3.40,64.00,'2023-07-24'),(20,4,7.00,79.00,'2023-07-24'),
(21,7,5.80,83.00,'2023-07-25'),(22,9,3.10,67.00,'2023-07-25'),
(23,6,4.70,52.00,'2023-07-26'),(24,8,3.90,74.00,'2023-07-26'),
(25,17,2.20,95.00,'2023-07-27');
-- =============================================================
-- USEFUL QUERIES FOR REFERENCE
-- =============================================================
-- Find suitable crops for land #1 based on its latest soil test:
--   CALL GetSuitableCrops(1);
--
-- Get best crop recommendation for land #5:
--   CALL GetBestCrop(5);
--
-- View all high-sustainability recommendations with farmer details:
--   SELECT * FROM High_Sustainability;
--
-- Check which crops match land #8's soil profile:
--   SELECT crop_name, suitability, avg_market_price
--   FROM Crop_Soil_Match
--   WHERE land_id = 8 AND suitability = 'SUITABLE'
--   ORDER BY avg_market_price DESC;
-- =============================================================
