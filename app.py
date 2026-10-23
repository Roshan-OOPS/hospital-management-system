import os
from datetime import date

import mysql.connector
from mysql.connector import Error
from flask import Flask, render_template, request, redirect, flash

app = Flask(__name__)
app.secret_key = "change-this-for-real-use"


# ---------- database helpers ----------

def get_conn():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        database=os.getenv("DB_NAME", "hospital_db"),
    )


def rows(sql, args=()):
    conn = get_conn()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute(sql, args)
        return cur.fetchall()
    finally:
        conn.close()


def execute(sql, args=()):
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.execute(sql, args)
        conn.commit()
    finally:
        conn.close()


def call_proc(name, args):
    conn = get_conn()
    try:
        cur = conn.cursor()
        cur.callproc(name, args)
        conn.commit()
    finally:
        conn.close()


def attempt(action, success):
    """Run a DB action and flash either the success text or the MySQL error."""
    try:
        action()
        flash(success, "ok")
    except Error as e:
        flash(e.msg, "error")


def clean(value):
    value = (value or "").strip()
    return value or None


# ---------- dashboard ----------

@app.route("/")
def index():
    one = lambda sql: rows(sql)[0]["n"]
    stats = [
        ("Patients", one("SELECT COUNT(*) AS n FROM patient")),
        ("Doctors", one("SELECT COUNT(*) AS n FROM doctor")),
        ("Scheduled appointments", one("SELECT COUNT(*) AS n FROM appointment WHERE status='Scheduled'")),
        ("Rooms occupied", one("SELECT COUNT(*) AS n FROM room WHERE status='Occupied'")),
        ("Revenue collected", "Rs. %s" % one("SELECT COALESCE(SUM(amount),0) AS n FROM payment")),
    ]
    upcoming = rows("SELECT * FROM appointment_details WHERE status='Scheduled' "
                    "ORDER BY appt_date, appt_time LIMIT 8")
    return render_template(
        "page.html", title="Dashboard", stats=stats,
        table_title="Next scheduled appointments",
        columns=[("patient", "Patient"), ("doctor", "Doctor"), ("appt_date", "Date"), ("appt_time", "Time")],
        rows=upcoming, empty="Nothing scheduled. Book one from the Appointments page.")


# ---------- patients ----------

@app.route("/patients", methods=["GET", "POST"])
def patients():
    if request.method == "POST":
        f = request.form
        attempt(lambda: execute(
            "INSERT INTO patient (name, age, gender, phone, address, blood_group) VALUES (%s,%s,%s,%s,%s,%s)",
            (f["name"], f["age"], f["gender"], clean(f["phone"]), clean(f["address"]), clean(f["blood_group"]))),
            "Patient added.")
        return redirect("/patients")
    form = {
        "title": "Add a patient", "action": "/patients", "submit": "Add patient",
        "fields": [
            {"name": "name", "label": "Full name"},
            {"name": "age", "label": "Age", "type": "number"},
            {"name": "gender", "label": "Gender", "options": [("Male", "Male"), ("Female", "Female"), ("Other", "Other")]},
            {"name": "phone", "label": "Phone", "required": False},
            {"name": "address", "label": "Address", "required": False},
            {"name": "blood_group", "label": "Blood group", "required": False},
        ],
    }
    return render_template(
        "page.html", title="Patients", form=form, table_title="All patients",
        columns=[("patient_id", "ID"), ("name", "Name"), ("age", "Age"), ("gender", "Gender"),
                 ("phone", "Phone"), ("blood_group", "Blood group")],
        rows=rows("SELECT * FROM patient ORDER BY patient_id DESC"), empty="No patients yet.")


# ---------- doctors ----------

@app.route("/doctors", methods=["GET", "POST"])
def doctors():
    if request.method == "POST":
        f = request.form
        attempt(lambda: execute(
            "INSERT INTO doctor (name, specialization, phone, fee, dept_id) VALUES (%s,%s,%s,%s,%s)",
            (f["name"], clean(f["specialization"]), clean(f["phone"]), f["fee"], f["dept_id"])),
            "Doctor added.")
        return redirect("/doctors")
    depts = [(d["dept_id"], d["dept_name"]) for d in rows("SELECT * FROM department")]
    form = {
        "title": "Add a doctor", "action": "/doctors", "submit": "Add doctor",
        "fields": [
            {"name": "name", "label": "Name"},
            {"name": "specialization", "label": "Specialization", "required": False},
            {"name": "phone", "label": "Phone", "required": False},
            {"name": "fee", "label": "Consultation fee", "type": "number"},
            {"name": "dept_id", "label": "Department", "options": depts},
        ],
    }
    return render_template(
        "page.html", title="Doctors", form=form, table_title="All doctors",
        columns=[("doctor_id", "ID"), ("name", "Name"), ("specialization", "Specialization"),
                 ("dept_name", "Department"), ("fee", "Fee")],
        rows=rows("SELECT d.*, dep.dept_name FROM doctor d JOIN department dep ON d.dept_id = dep.dept_id "
                  "ORDER BY d.doctor_id"),
        empty="No doctors yet.")


# ---------- appointments ----------

@app.route("/appointments", methods=["GET", "POST"])
def appointments():
    if request.method == "POST":
        f = request.form
        attempt(lambda: call_proc("book_appointment",
                                  (f["patient_id"], f["doctor_id"], f["appt_date"], f["appt_time"])),
                "Appointment booked.")
        return redirect("/appointments")
    pats = [(p["patient_id"], p["name"]) for p in rows("SELECT patient_id, name FROM patient ORDER BY name")]
    docs = [(d["doctor_id"], "%s (%s)" % (d["name"], d["specialization"]))
            for d in rows("SELECT doctor_id, name, specialization FROM doctor ORDER BY name")]
    form = {
        "title": "Book an appointment", "action": "/appointments", "submit": "Book appointment",
        "fields": [
            {"name": "patient_id", "label": "Patient", "options": pats},
            {"name": "doctor_id", "label": "Doctor", "options": docs},
            {"name": "appt_date", "label": "Date", "type": "date", "default": date.today().isoformat()},
            {"name": "appt_time", "label": "Time", "type": "time"},
        ],
    }
    data = rows("SELECT * FROM appointment_details ORDER BY appt_date DESC, appt_time DESC")
    for r in data:
        if r["status"] == "Scheduled":
            r["actions"] = [
                {"label": "Collect fee", "url": "/appointments/%s/pay" % r["appointment_id"], "kind": "pay"},
                {"label": "Cancel", "url": "/appointments/%s/cancel" % r["appointment_id"], "kind": "danger"},
            ]
    return render_template(
        "page.html", title="Appointments", form=form, table_title="All appointments",
        columns=[("appointment_id", "ID"), ("patient", "Patient"), ("doctor", "Doctor"),
                 ("appt_date", "Date"), ("appt_time", "Time"), ("status", "Status")],
        rows=data, empty="No appointments yet.", badge="status")


@app.route("/appointments/<int:appt_id>/pay", methods=["POST"])
def pay(appt_id):
    fee = rows("SELECT d.fee FROM appointment a JOIN doctor d ON a.doctor_id = d.doctor_id "
               "WHERE a.appointment_id = %s", (appt_id,))
    if fee:
        # the trigger marks the appointment as Completed
        attempt(lambda: execute(
            "INSERT INTO payment (appointment_id, amount, mode, paid_on) VALUES (%s,%s,%s,CURDATE())",
            (appt_id, fee[0]["fee"], request.form.get("mode", "Cash"))), "Payment recorded.")
    return redirect("/appointments")


@app.route("/appointments/<int:appt_id>/cancel", methods=["POST"])
def cancel(appt_id):
    attempt(lambda: execute("UPDATE appointment SET status='Cancelled' WHERE appointment_id=%s", (appt_id,)),
            "Appointment cancelled.")
    return redirect("/appointments")


# ---------- admissions ----------

@app.route("/admissions", methods=["GET", "POST"])
def admissions():
    if request.method == "POST":
        f = request.form
        attempt(lambda: execute(
            "INSERT INTO admission (patient_id, room_id, admit_date) VALUES (%s,%s,%s)",
            (f["patient_id"], f["room_id"], f["admit_date"])), "Patient admitted.")
        return redirect("/admissions")
    pats = [(p["patient_id"], p["name"]) for p in rows("SELECT patient_id, name FROM patient ORDER BY name")]
    free = [(r["room_id"], "Room %s, %s (Rs. %s/day)" % (r["room_id"], r["room_type"], r["charge_per_day"]))
            for r in rows("SELECT * FROM room WHERE status='Available'")]
    form = {
        "title": "Admit a patient", "action": "/admissions", "submit": "Admit patient",
        "fields": [
            {"name": "patient_id", "label": "Patient", "options": pats},
            {"name": "room_id", "label": "Available room", "options": free},
            {"name": "admit_date", "label": "Admit date", "type": "date", "default": date.today().isoformat()},
        ],
    }
    data = rows("SELECT ad.admission_id, p.name AS patient, r.room_id, r.room_type, ad.admit_date, "
                "ad.discharge_date, "
                "IF(ad.discharge_date IS NULL, 'Admitted', 'Discharged') AS status "
                "FROM admission ad JOIN patient p ON ad.patient_id = p.patient_id "
                "JOIN room r ON ad.room_id = r.room_id ORDER BY ad.admission_id DESC")
    for r in data:
        if r["status"] == "Admitted":
            r["actions"] = [{"label": "Discharge", "url": "/admissions/%s/discharge" % r["admission_id"],
                             "kind": "plain"}]
    return render_template(
        "page.html", title="Admissions", form=form, table_title="Admissions",
        columns=[("patient", "Patient"), ("room_id", "Room"), ("room_type", "Type"),
                 ("admit_date", "Admitted"), ("discharge_date", "Discharged"), ("status", "Status")],
        rows=data, empty="No admissions yet.", badge="status")


@app.route("/admissions/<int:adm_id>/discharge", methods=["POST"])
def discharge(adm_id):
    # the trigger frees the room
    attempt(lambda: execute("UPDATE admission SET discharge_date=CURDATE() WHERE admission_id=%s", (adm_id,)),
            "Patient discharged and room freed.")
    return redirect("/admissions")


if __name__ == "__main__":
    app.run(debug=True)
