-- ==============================================================================
-- 1. DATABASE SCHEMA CREATION
-- ==============================================================================
CREATE DATABASE IF NOT EXISTS `laravel_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `wordpress_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- ==============================================================================
-- 2. DEDICATED APPLICATION USER CREATION
-- ==============================================================================
-- Create a secure, isolated user for the Laravel API container
CREATE USER IF NOT EXISTS 'laravel_user'@'%' IDENTIFIED BY 'laravel_local_secure_pwd';

-- Create a secure, isolated user for the Headless WordPress container
CREATE USER IF NOT EXISTS 'wordpress_user'@'%' IDENTIFIED BY 'wordpress_local_secure_pwd';

-- ==============================================================================
-- 3. ISOLATED PRIVILEGE SCOPING (Least Privilege Principle)
-- ==============================================================================
-- Restrict the Laravel user strictly to its own operational schema database
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, REFERENCES 
    ON `laravel_db`.* TO 'laravel_user'@'%';

-- Restrict the WordPress user strictly to its own operational schema database
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, REFERENCES 
    ON `wordpress_db`.* TO 'wordpress_user'@'%';

-- ==============================================================================
-- 4. ROOT MAINTENANCE & PRIVILEGE COMMIT
-- ==============================================================================
-- Maintain broad network privileges for the root operator for local GUI connections
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;

-- Flush privileges to write changes to memory immediately
FLUSH PRIVILEGES;
