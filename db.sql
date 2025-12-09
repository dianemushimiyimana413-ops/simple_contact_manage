-- Create the database and contacts table used by the application.
CREATE DATABASE IF NOT EXISTS contacts_db;
USE contacts_db;

CREATE TABLE IF NOT EXISTS contacts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  phone VARCHAR(50),
  email VARCHAR(255)
);

INSERT INTO contacts (name, phone, email) VALUES
  ('Alice Example', '555-0100', 'alice@example.com'),
  ('Bob Example', '555-0110', 'bob@example.com');
