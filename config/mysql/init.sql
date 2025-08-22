-- config/mysql/init.sql
-- This script runs when MySQL container starts up

-- Create all required databases
CREATE DATABASE IF NOT EXISTS heimdall_production;
CREATE DATABASE IF NOT EXISTS heimdall_production_cache;
CREATE DATABASE IF NOT EXISTS heimdall_production_queue;
CREATE DATABASE IF NOT EXISTS heimdall_production_cable;
CREATE DATABASE IF NOT EXISTS freeradius;

-- The MYSQL_USER and MYSQL_PASSWORD environment variables are automatically 
-- used by the MySQL Docker image to create the user defined in docker-compose/kamal config
-- So we just need to grant additional permissions to the auto-created user

-- Grant permissions on all heimdall databases to the auto-created user
GRANT ALL PRIVILEGES ON heimdall_production.* TO 'heimdall'@'%';
GRANT ALL PRIVILEGES ON heimdall_production_cache.* TO 'heimdall'@'%';
GRANT ALL PRIVILEGES ON heimdall_production_queue.* TO 'heimdall'@'%';
GRANT ALL PRIVILEGES ON heimdall_production_cable.* TO 'heimdall'@'%';
GRANT ALL PRIVILEGES ON freeradius.* TO 'heimdall'@'%';

FLUSH PRIVILEGES;
