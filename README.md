# Hospital Management System (Flask + MySQL)

## Setup
1. Install Python 3 and MySQL, and make sure MySQL is running.
2. Create the database (tables, triggers, procedure, sample data):
   mysql -u root -p < hospital_management.sql
3. Install the Python packages:
   pip install -r requirements.txt
4. Tell the app your MySQL password (skip if your root password is empty):
   Windows:    set DB_PASSWORD=yourpassword
   Mac/Linux:  export DB_PASSWORD=yourpassword
   (Optional: DB_HOST, DB_USER, DB_NAME also work.)
5. Start the app:
   python app.py
6. Open http://127.0.0.1:5000

## What each page does
- Dashboard: counts, revenue and the next scheduled appointments
- Patients / Doctors: add and list records
- Appointments: book (uses the book_appointment stored procedure, so double-booking is blocked),
  collect fee (inserts a payment, and a trigger marks the appointment Completed), cancel
- Admissions: admit into an available room (trigger marks it Occupied), discharge (trigger frees it)
