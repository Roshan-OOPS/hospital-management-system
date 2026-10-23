-- ============================================================
-- HOSPITAL MANAGEMENT SYSTEM (DBMS Mini Project)
-- Database: MySQL 8.x
-- ============================================================

DROP DATABASE IF EXISTS hospital_db;
CREATE DATABASE hospital_db;
USE hospital_db;

-- ------------------------------------------------------------
-- 1. TABLES
-- ------------------------------------------------------------

CREATE TABLE department (
    dept_id     INT PRIMARY KEY AUTO_INCREMENT,
    dept_name   VARCHAR(50) NOT NULL UNIQUE,
    location    VARCHAR(50)
);

CREATE TABLE doctor (
    doctor_id       INT PRIMARY KEY AUTO_INCREMENT,
    name            VARCHAR(60) NOT NULL,
    specialization  VARCHAR(60),
    phone           VARCHAR(15),
    fee             DECIMAL(8,2) NOT NULL CHECK (fee >= 0),
    dept_id         INT NOT NULL,
    FOREIGN KEY (dept_id) REFERENCES department(dept_id)
);

CREATE TABLE patient (
    patient_id   INT PRIMARY KEY AUTO_INCREMENT,
    name         VARCHAR(60) NOT NULL,
    age          INT CHECK (age > 0),
    gender       ENUM('Male','Female','Other'),
    phone        VARCHAR(15),
    address      VARCHAR(120),
    blood_group  VARCHAR(5)
);

CREATE TABLE room (
    room_id          INT PRIMARY KEY AUTO_INCREMENT,
    room_type        ENUM('General','Semi-Private','Private','ICU') NOT NULL,
    charge_per_day   DECIMAL(8,2) NOT NULL,
    status           ENUM('Available','Occupied') DEFAULT 'Available'
);

CREATE TABLE appointment (
    appointment_id  INT PRIMARY KEY AUTO_INCREMENT,
    patient_id      INT NOT NULL,
    doctor_id       INT NOT NULL,
    appt_date       DATE NOT NULL,
    appt_time       TIME NOT NULL,
    status          ENUM('Scheduled','Completed','Cancelled') DEFAULT 'Scheduled',
    FOREIGN KEY (patient_id) REFERENCES patient(patient_id),
    FOREIGN KEY (doctor_id)  REFERENCES doctor(doctor_id),
    UNIQUE (doctor_id, appt_date, appt_time)   -- a doctor can't have two patients at the same time
);

CREATE TABLE prescription (
    prescription_id  INT PRIMARY KEY AUTO_INCREMENT,
    appointment_id   INT NOT NULL,
    medicine         VARCHAR(80) NOT NULL,
    dosage           VARCHAR(50),
    notes            VARCHAR(150),
    FOREIGN KEY (appointment_id) REFERENCES appointment(appointment_id)
);

CREATE TABLE admission (
    admission_id    INT PRIMARY KEY AUTO_INCREMENT,
    patient_id      INT NOT NULL,
    room_id         INT NOT NULL,
    admit_date      DATE NOT NULL,
    discharge_date  DATE NULL,
    FOREIGN KEY (patient_id) REFERENCES patient(patient_id),
    FOREIGN KEY (room_id)    REFERENCES room(room_id)
);

CREATE TABLE payment (
    payment_id      INT PRIMARY KEY AUTO_INCREMENT,
    appointment_id  INT NOT NULL,
    amount          DECIMAL(8,2) NOT NULL,
    mode            ENUM('Cash','Card','UPI') NOT NULL,
    paid_on         DATE NOT NULL,
    FOREIGN KEY (appointment_id) REFERENCES appointment(appointment_id)
);

-- ------------------------------------------------------------
-- 2. TRIGGERS
-- ------------------------------------------------------------

DELIMITER //

-- When a payment is added, mark that appointment as Completed
CREATE TRIGGER trg_payment_complete
AFTER INSERT ON payment
FOR EACH ROW
BEGIN
    UPDATE appointment
    SET status = 'Completed'
    WHERE appointment_id = NEW.appointment_id;
END//

-- When a patient is admitted, mark the room as Occupied
CREATE TRIGGER trg_admit_room
AFTER INSERT ON admission
FOR EACH ROW
BEGIN
    UPDATE room SET status = 'Occupied' WHERE room_id = NEW.room_id;
END//

-- When a patient is discharged, free the room
CREATE TRIGGER trg_discharge_room
AFTER UPDATE ON admission
FOR EACH ROW
BEGIN
    IF OLD.discharge_date IS NULL AND NEW.discharge_date IS NOT NULL THEN
        UPDATE room SET status = 'Available' WHERE room_id = NEW.room_id;
    END IF;
END//

-- ------------------------------------------------------------
-- 3. STORED PROCEDURE
-- ------------------------------------------------------------

-- Book an appointment, but refuse if the doctor already has that slot
CREATE PROCEDURE book_appointment(
    IN p_patient INT,
    IN p_doctor  INT,
    IN p_date    DATE,
    IN p_time    TIME
)
BEGIN
    IF EXISTS (
        SELECT 1 FROM appointment
        WHERE doctor_id = p_doctor
          AND appt_date = p_date
          AND appt_time = p_time
          AND status <> 'Cancelled'
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Doctor is already booked for this slot';
    ELSE
        INSERT INTO appointment (patient_id, doctor_id, appt_date, appt_time)
        VALUES (p_patient, p_doctor, p_date, p_time);
    END IF;
END//

DELIMITER ;

-- ------------------------------------------------------------
-- 4. SAMPLE DATA
-- ------------------------------------------------------------

INSERT INTO department (dept_name, location) VALUES
('Cardiology',  'Block A, Floor 2'),
('Orthopedics', 'Block B, Floor 1'),
('Pediatrics',  'Block A, Floor 1'),
('General Medicine', 'Block C, Floor 1');

INSERT INTO doctor (name, specialization, phone, fee, dept_id) VALUES
('Dr. Anil Menon',    'Cardiologist',       '9847000001', 800.00, 1),
('Dr. Sneha Pillai',  'Orthopedic Surgeon', '9847000002', 700.00, 2),
('Dr. Rahul Nair',    'Pediatrician',       '9847000003', 500.00, 3),
('Dr. Meera Thomas',  'General Physician',  '9847000004', 400.00, 4),
('Dr. Joseph Kurian', 'Cardiologist',       '9847000005', 900.00, 1);

INSERT INTO patient (name, age, gender, phone, address, blood_group) VALUES
('Arjun Das',      34, 'Male',   '9400000001', 'Kumily',     'O+'),
('Fathima Beevi',  52, 'Female', '9400000002', 'Thekkady',   'A+'),
('Rohan Mathew',    8, 'Male',   '9400000003', 'Kumily',     'B+'),
('Lakshmi Nair',   45, 'Female', '9400000004', 'Vandiperiyar','AB+'),
('Sibi Joseph',    61, 'Male',   '9400000005', 'Kumily',     'O-'),
('Anjali Menon',   27, 'Female', '9400000006', 'Thekkady',   'A-'),
('Imran Khan',     39, 'Male',   '9400000007', 'Kumily',     'B-'),
('Divya Raj',      5,  'Female', '9400000008', 'Vandiperiyar','O+');

INSERT INTO room (room_type, charge_per_day, status) VALUES
('General',      800.00,  'Available'),
('General',      800.00,  'Available'),
('Semi-Private', 1500.00, 'Available'),
('Private',      2500.00, 'Available'),
('ICU',          6000.00, 'Available');

INSERT INTO appointment (patient_id, doctor_id, appt_date, appt_time, status) VALUES
(1, 4, '2026-10-20', '10:00:00', 'Scheduled'),
(2, 1, '2026-10-20', '11:00:00', 'Scheduled'),
(3, 3, '2026-10-21', '09:30:00', 'Scheduled'),
(4, 2, '2026-10-21', '10:30:00', 'Scheduled'),
(5, 1, '2026-10-22', '11:00:00', 'Scheduled'),
(1, 4, '2026-10-23', '10:00:00', 'Scheduled'),
(6, 4, '2026-10-24', '12:00:00', 'Scheduled'),
(7, 5, '2026-10-24', '15:00:00', 'Scheduled'),
(8, 3, '2026-10-25', '09:30:00', 'Scheduled'),
(2, 1, '2026-10-26', '11:00:00', 'Scheduled');

INSERT INTO prescription (appointment_id, medicine, dosage, notes) VALUES
(1, 'Paracetamol',  '500mg twice daily', 'After food'),
(2, 'Atorvastatin', '10mg at night',     'Review in 2 weeks'),
(2, 'Aspirin',      '75mg once daily',   'After breakfast'),
(3, 'Amoxicillin',  '250mg thrice daily','5 day course'),
(4, 'Ibuprofen',    '400mg twice daily', 'Rest advised'),
(5, 'Metoprolol',   '25mg once daily',   'Monitor BP');

-- These inserts fire the trigger, so these appointments become Completed
INSERT INTO payment (appointment_id, amount, mode, paid_on) VALUES
(1, 400.00, 'Cash', '2026-10-20'),
(2, 800.00, 'Card', '2026-10-20'),
(3, 500.00, 'UPI',  '2026-10-21'),
(4, 700.00, 'Cash', '2026-10-21'),
(5, 800.00, 'UPI',  '2026-10-22'),
(6, 400.00, 'Cash', '2026-10-23');

-- These inserts fire the trigger, so the rooms become Occupied
INSERT INTO admission (patient_id, room_id, admit_date, discharge_date) VALUES
(5, 5, '2026-10-22', NULL),
(4, 3, '2026-10-21', '2026-10-24'),
(2, 4, '2026-10-24', NULL);

-- Discharging Lakshmi fires the discharge trigger and frees room 3
UPDATE admission SET discharge_date = '2026-10-24' WHERE admission_id = 2;

-- ------------------------------------------------------------
-- 5. VIEW
-- ------------------------------------------------------------

CREATE VIEW appointment_details AS
SELECT a.appointment_id,
       p.name  AS patient,
       d.name  AS doctor,
       d.specialization,
       a.appt_date,
       a.appt_time,
       a.status
FROM appointment a
JOIN patient p ON a.patient_id = p.patient_id
JOIN doctor  d ON a.doctor_id  = d.doctor_id;

-- ------------------------------------------------------------
-- 6. QUERIES
-- ------------------------------------------------------------

-- Q1: Use the view to see every appointment
SELECT * FROM appointment_details ORDER BY appt_date, appt_time;

-- Q2: All appointments for one doctor
SELECT * FROM appointment_details WHERE doctor = 'Dr. Anil Menon';

-- Q3: Total earnings per doctor
SELECT d.name, SUM(pay.amount) AS total_earned
FROM payment pay
JOIN appointment a ON pay.appointment_id = a.appointment_id
JOIN doctor d      ON a.doctor_id = d.doctor_id
GROUP BY d.doctor_id, d.name
ORDER BY total_earned DESC;

-- Q4: Patients who visited more than once
SELECT p.name, COUNT(*) AS visits
FROM appointment a
JOIN patient p ON a.patient_id = p.patient_id
GROUP BY p.patient_id, p.name
HAVING COUNT(*) > 1;

-- Q5: Pending (scheduled) appointments
SELECT * FROM appointment_details WHERE status = 'Scheduled';

-- Q6: Full prescription history for a patient
SELECT p.name AS patient, a.appt_date, pr.medicine, pr.dosage, pr.notes
FROM prescription pr
JOIN appointment a ON pr.appointment_id = a.appointment_id
JOIN patient p     ON a.patient_id = p.patient_id
WHERE p.name = 'Fathima Beevi';

-- Q7: Doctors per department (including departments with none)
SELECT dep.dept_name, COUNT(d.doctor_id) AS doctor_count
FROM department dep
LEFT JOIN doctor d ON dep.dept_id = d.dept_id
GROUP BY dep.dept_id, dep.dept_name;

-- Q8: Patients currently admitted, with room details
SELECT p.name, r.room_type, r.room_id, ad.admit_date
FROM admission ad
JOIN patient p ON ad.patient_id = p.patient_id
JOIN room r    ON ad.room_id = r.room_id
WHERE ad.discharge_date IS NULL;

-- Q9: Room bill for discharged patients (days stayed x daily charge)
SELECT p.name,
       DATEDIFF(ad.discharge_date, ad.admit_date) AS days_stayed,
       r.charge_per_day,
       DATEDIFF(ad.discharge_date, ad.admit_date) * r.charge_per_day AS room_bill
FROM admission ad
JOIN patient p ON ad.patient_id = p.patient_id
JOIN room r    ON ad.room_id = r.room_id
WHERE ad.discharge_date IS NOT NULL;

-- Q10: Patients above the average age
SELECT name, age FROM patient
WHERE age > (SELECT AVG(age) FROM patient);

-- Q11: Available rooms
SELECT room_id, room_type, charge_per_day FROM room WHERE status = 'Available';

-- Q12: Revenue by payment mode
SELECT mode, COUNT(*) AS payments, SUM(amount) AS total
FROM payment
GROUP BY mode;

-- ------------------------------------------------------------
-- 7. TEST THE PROCEDURE
-- ------------------------------------------------------------

-- This works (free slot)
CALL book_appointment(3, 3, '2026-10-27', '10:00:00');

-- This fails with "Doctor is already booked for this slot"
-- CALL book_appointment(1, 3, '2026-10-27', '10:00:00');
