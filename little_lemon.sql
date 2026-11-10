-- Little Lemon integrated operational + analytics database
-- MySQL 8.0+
CREATE DATABASE IF NOT EXISTS little_lemon;
USE little_lemon;

CREATE TABLE IF NOT EXISTS Customers (
  customer_id INT AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(80) NOT NULL,
  last_name VARCHAR(80) NOT NULL,
  email VARCHAR(160) NOT NULL UNIQUE,
  phone VARCHAR(30),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Employees (
  employee_id INT AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(80) NOT NULL,
  last_name VARCHAR(80) NOT NULL,
  role VARCHAR(60) NOT NULL,
  email VARCHAR(160) UNIQUE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS RestaurantTables (
  table_id INT AUTO_INCREMENT PRIMARY KEY,
  table_number INT NOT NULL UNIQUE,
  capacity INT NOT NULL CHECK (capacity > 0),
  location VARCHAR(80) DEFAULT 'Main dining room',
  is_active BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS Bookings (
  booking_id INT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NOT NULL,
  table_id INT NOT NULL,
  employee_id INT NULL,
  booking_date DATETIME NOT NULL,
  guests INT NOT NULL CHECK (guests > 0),
  booking_status ENUM('CONFIRMED','CANCELLED','COMPLETED','NO_SHOW') NOT NULL DEFAULT 'CONFIRMED',
  special_requests VARCHAR(500),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_booking_customer FOREIGN KEY (customer_id) REFERENCES Customers(customer_id),
  CONSTRAINT fk_booking_table FOREIGN KEY (table_id) REFERENCES RestaurantTables(table_id),
  CONSTRAINT fk_booking_employee FOREIGN KEY (employee_id) REFERENCES Employees(employee_id),
  INDEX idx_booking_date (booking_date),
  INDEX idx_booking_status (booking_status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS MenuItems (
  menu_item_id INT AUTO_INCREMENT PRIMARY KEY,
  item_name VARCHAR(120) NOT NULL,
  category VARCHAR(60) NOT NULL,
  cuisine VARCHAR(60),
  unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
  is_available BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS RestaurantOrders (
  restaurant_order_id INT AUTO_INCREMENT PRIMARY KEY,
  booking_id INT NULL,
  customer_id INT NOT NULL,
  order_datetime DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  order_status ENUM('PLACED','PREPARING','SERVED','CANCELLED') NOT NULL DEFAULT 'PLACED',
  CONSTRAINT fk_order_booking FOREIGN KEY (booking_id) REFERENCES Bookings(booking_id),
  CONSTRAINT fk_order_customer FOREIGN KEY (customer_id) REFERENCES Customers(customer_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS OrderItems (
  order_item_id INT AUTO_INCREMENT PRIMARY KEY,
  restaurant_order_id INT NOT NULL,
  menu_item_id INT NOT NULL,
  quantity INT NOT NULL CHECK (quantity > 0),
  unit_price DECIMAL(10,2) NOT NULL,
  CONSTRAINT fk_orderitem_order FOREIGN KEY (restaurant_order_id) REFERENCES RestaurantOrders(restaurant_order_id),
  CONSTRAINT fk_orderitem_menu FOREIGN KEY (menu_item_id) REFERENCES MenuItems(menu_item_id)
) ENGINE=InnoDB;

-- Analytics star schema: one row per source workbook line.
CREATE TABLE IF NOT EXISTS DimCustomer (
  customer_key INT AUTO_INCREMENT PRIMARY KEY,
  source_customer_id VARCHAR(40) NOT NULL UNIQUE,
  customer_name VARCHAR(160) NOT NULL
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS DimGeography (
  geography_key INT AUTO_INCREMENT PRIMARY KEY,
  city VARCHAR(120), country VARCHAR(120), postal_code VARCHAR(30), country_code VARCHAR(8),
  UNIQUE KEY uq_geo (city,country,postal_code)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS DimMenu (
  menu_key INT AUTO_INCREMENT PRIMARY KEY,
  course_name VARCHAR(100), cuisine_name VARCHAR(80), starter_name VARCHAR(100),
  dessert_name VARCHAR(100), drink VARCHAR(100), sides VARCHAR(100),
  UNIQUE KEY uq_menu (course_name,cuisine_name,starter_name,dessert_name,drink,sides)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS DimDate (
  date_key INT PRIMARY KEY,
  full_date DATE NOT NULL,
  year_num SMALLINT NOT NULL,
  quarter_num TINYINT NOT NULL,
  month_num TINYINT NOT NULL,
  month_name VARCHAR(15) NOT NULL,
  day_num TINYINT NOT NULL
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS FactSales (
  sales_key BIGINT AUTO_INCREMENT PRIMARY KEY,
  source_row_number INT NOT NULL UNIQUE,
  order_id VARCHAR(40) NOT NULL,
  customer_key INT NOT NULL,
  geography_key INT NOT NULL,
  menu_key INT NOT NULL,
  order_date_key INT NOT NULL,
  delivery_date_key INT NOT NULL,
  cost DECIMAL(12,2) NOT NULL,
  sales DECIMAL(12,2) NOT NULL,
  quantity INT NOT NULL,
  discount DECIMAL(8,2) NOT NULL,
  delivery_cost DECIMAL(12,2) NOT NULL,
  gross_profit DECIMAL(12,2) NOT NULL,
  CONSTRAINT fk_fact_customer FOREIGN KEY(customer_key) REFERENCES DimCustomer(customer_key),
  CONSTRAINT fk_fact_geo FOREIGN KEY(geography_key) REFERENCES DimGeography(geography_key),
  CONSTRAINT fk_fact_menu FOREIGN KEY(menu_key) REFERENCES DimMenu(menu_key),
  CONSTRAINT fk_fact_orderdate FOREIGN KEY(order_date_key) REFERENCES DimDate(date_key),
  CONSTRAINT fk_fact_deliverydate FOREIGN KEY(delivery_date_key) REFERENCES DimDate(date_key),
  INDEX idx_fact_order_id(order_id)
) ENGINE=InnoDB;

-- Required booking procedures
DELIMITER //
DROP PROCEDURE IF EXISTS GetMaxQuantity//
CREATE PROCEDURE GetMaxQuantity()
BEGIN
  SELECT COALESCE(MAX(guests),0) AS max_booking_guests FROM Bookings;
END//

DROP PROCEDURE IF EXISTS ManageBooking//
CREATE PROCEDURE ManageBooking(IN p_booking_id INT)
BEGIN
  IF EXISTS (SELECT 1 FROM Bookings WHERE booking_id=p_booking_id AND booking_status='CONFIRMED') THEN
    SELECT 'Booking exists and is confirmed' AS booking_result;
  ELSEIF EXISTS (SELECT 1 FROM Bookings WHERE booking_id=p_booking_id) THEN
    SELECT 'Booking exists but is not confirmed' AS booking_result;
  ELSE
    SELECT 'Booking does not exist' AS booking_result;
  END IF;
END//

DROP PROCEDURE IF EXISTS UpdateBooking//
CREATE PROCEDURE UpdateBooking(
  IN p_booking_id INT, IN p_booking_date DATETIME,
  IN p_table_id INT, IN p_guests INT
)
BEGIN
  IF p_guests <= 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Guests must be greater than zero'; END IF;
  IF NOT EXISTS (SELECT 1 FROM Bookings WHERE booking_id=p_booking_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Booking not found';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM RestaurantTables WHERE table_id=p_table_id
    AND is_active=TRUE AND capacity>=p_guests) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Table is inactive, missing, or too small';
  END IF;
  UPDATE Bookings SET booking_date=p_booking_date, table_id=p_table_id, guests=p_guests
  WHERE booking_id=p_booking_id AND booking_status='CONFIRMED';
  SELECT ROW_COUNT() AS rows_updated;
END//

DROP PROCEDURE IF EXISTS AddBooking//
CREATE PROCEDURE AddBooking(
  IN p_customer_id INT, IN p_booking_date DATETIME,
  IN p_table_id INT, IN p_guests INT
)
BEGIN
  IF p_guests <= 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Guests must be greater than zero'; END IF;
  IF NOT EXISTS (SELECT 1 FROM Customers WHERE customer_id=p_customer_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Customer not found';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM RestaurantTables WHERE table_id=p_table_id AND is_active=TRUE AND capacity>=p_guests) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Table is inactive, missing, or too small';
  END IF;
  IF EXISTS (SELECT 1 FROM Bookings WHERE table_id=p_table_id AND booking_status='CONFIRMED'
    AND ABS(TIMESTAMPDIFF(MINUTE,booking_date,p_booking_date)) < 120) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Table is already booked within the two-hour window';
  END IF;
  INSERT INTO Bookings(customer_id,table_id,booking_date,guests)
  VALUES(p_customer_id,p_table_id,p_booking_date,p_guests);
  SELECT LAST_INSERT_ID() AS new_booking_id;
END//

DROP PROCEDURE IF EXISTS CancelBooking//
CREATE PROCEDURE CancelBooking(IN p_booking_id INT)
BEGIN
  UPDATE Bookings SET booking_status='CANCELLED'
  WHERE booking_id=p_booking_id AND booking_status='CONFIRMED';
  SELECT ROW_COUNT() AS rows_cancelled;
END//
DELIMITER ;

-- Minimal reference data for testing (safe to run repeatedly).
INSERT IGNORE INTO RestaurantTables(table_id,table_number,capacity,location) VALUES
(1,1,2,'Window'),(2,2,4,'Main dining room'),(3,3,6,'Patio'),(4,4,8,'Private dining');
INSERT IGNORE INTO Employees(employee_id,first_name,last_name,role,email) VALUES
(1,'Alex','Morgan','Manager','alex.manager@littlelemon.example');
INSERT IGNORE INTO Customers(customer_id,first_name,last_name,email,phone) VALUES
(1,'Jamie','Smith','jamie.smith@example.com','+10000000000'),
(2,'Taylor','Jones','taylor.jones@example.com','+10000000001');
INSERT IGNORE INTO MenuItems(menu_item_id,item_name,category,cuisine,unit_price) VALUES
(1,'Greek Salad','Main','Greek',12.50),(2,'Bean Soup','Starter','Italian',8.00),
(3,'Pizza','Main','Italian',15.00),(4,'Cheesecake','Dessert','International',6.50);
