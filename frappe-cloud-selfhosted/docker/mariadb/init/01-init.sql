-- ============================================
-- MariaDB Initialization Script
-- ============================================

-- Create databases
CREATE DATABASE IF NOT EXISTS press 
    CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;

-- Grant full privileges to root from any host
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY PASSWORD '*' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;

-- Flush privileges
FLUSH PRIVILEGES;

-- Show created databases
SHOW DATABASES;
