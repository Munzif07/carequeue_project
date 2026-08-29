-- ============================================================
--  CareQueue Database — carequeue.sql
--  phpMyAdmin → New DB "carequeue" → Import this file
-- ============================================================

CREATE DATABASE IF NOT EXISTS carequeue;
USE carequeue;

CREATE TABLE IF NOT EXISTS clinics (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  clinic_id   VARCHAR(20)  UNIQUE NOT NULL,
  name        VARCHAR(100) NOT NULL,
  doctor_name VARCHAR(100) NOT NULL,
  password    VARCHAR(255) NOT NULL,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS patients (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  nic        VARCHAR(20)  NOT NULL UNIQUE,
  phone      VARCHAR(15)  NOT NULL,
  gmail      VARCHAR(100) UNIQUE NOT NULL,
  patid      VARCHAR(10)  NOT NULL,
  clinic_id  VARCHAR(20)  NOT NULL,
  password   VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_patid_clinic (patid, clinic_id)
);

CREATE TABLE IF NOT EXISTS clinic_dates (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  clinic_id     VARCHAR(20) NOT NULL,
  schedule_date DATE        NOT NULL,
  opening_time  VARCHAR(20),
  closing_time  VARCHAR(20),
  max_patients  INT DEFAULT 20,
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_clinic_date (clinic_id, schedule_date),
  FOREIGN KEY (clinic_id) REFERENCES clinics(clinic_id)
);

CREATE TABLE IF NOT EXISTS bookings (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  patient_id    INT         NOT NULL,
  clinic_id     VARCHAR(20) NOT NULL,
  schedule_date DATE        NOT NULL,
  token_number  INT         NOT NULL,
  status        ENUM('waiting','done','skipped') DEFAULT 'waiting',
  booked_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(id),
  FOREIGN KEY (clinic_id)  REFERENCES clinics(clinic_id)
);

-- Demo Clinic  (password: doctor123)
INSERT IGNORE INTO clinics (clinic_id, name, doctor_name, password)
VALUES ('CLN-2024-001','Sri Murugan Clinic','Dr. Senthil Kumar',
'$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi');

-- Demo Patient (password: patient123)
INSERT IGNORE INTO patients (name, nic, phone, gmail, patid, clinic_id, password)
VALUES ('Arun Kumar','991234567V','0771234567','arun@gmail.com','P-0001','CLN-2024-001',
'$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi');
