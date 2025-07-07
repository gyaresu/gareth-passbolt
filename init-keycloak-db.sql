-- Create Keycloak database
CREATE DATABASE IF NOT EXISTS keycloak CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Grant all privileges to the passbolt user for the keycloak database
GRANT ALL PRIVILEGES ON keycloak.* TO 'passbolt'@'%';

-- Apply changes
FLUSH PRIVILEGES; 