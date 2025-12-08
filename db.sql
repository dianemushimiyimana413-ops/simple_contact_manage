-- Create a database named 'contacts_db' if it doesn't exist
CREATE DATABASE IF NOT EXISTS contacts_db;

-- Use the database
USE contacts_db;

-- Create the 'contacts' table if it doesn't exist
CREATE TABLE IF NOT EXISTS contacts (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE
);

-- Insert some sample data into the 'contacts' table
INSERT INTO contacts (name, phone, email) VALUES 
('John Doe', '123-456-7890', 'john.doe@example.com'),
('Jane Smith', '987-654-3210', 'jane.smith@example.com'),
('Emily Johnson', '555-123-9876', 'emily.johnson@example.com');
