import sys
import os
sys.path.insert(0, os.path.abspath('.'))
from backend.app.database import SessionLocal, Base, engine
from backend.app.models import AppUser, Employee, Client

db = SessionLocal()
print('Seeding clean user accounts...')

# Ensure Client
c1 = db.query(Client).filter(Client.company_name == 'CarePlus Telehealth Systems').first()
if not c1:
    c1 = Client(company_name='CarePlus Telehealth Systems', industry='Healthcare SaaS', contact_email='billing@careplus.io', billing_tier='enterprise', sla_response_hours=4)
    db.add(c1)
    db.commit()

# Ensure Employees
def get_or_create_emp(name, email, desig, dept, rate):
    emp = db.query(Employee).filter(Employee.work_email == email).first()
    if not emp:
        emp = Employee(full_name=name, work_email=email, designation=desig, department=dept, hourly_rate=rate, weekly_capacity_hours=40.0)
        db.add(emp)
        db.commit()
    return emp

e_ceo = get_or_create_emp('Kavindu Kaveesha', 'kavindu@helanexus.com', 'Founder & CEO', 'leadership', 120.0)
e_pm = get_or_create_emp('Dilshan Gamage', 'dilshan@helanexus.com', 'Lead Project Manager & Architect', 'engineering', 85.0)
e_dev = get_or_create_emp('Bimsari Perera', 'bimsari@helanexus.com', 'Senior Database & QA Engineer', 'engineering', 80.0)
e_dev2 = get_or_create_emp('Nimna Jayawardhana', 'nimna@helanexus.com', 'Senior Full-Stack Engineer', 'engineering', 75.0)

def upsert_user(uname, emp_id, role):
    u = db.query(AppUser).filter(AppUser.username == uname).first()
    if not u:
        u = AppUser(
            employee_id=emp_id,
            username=uname,
            password_hash='Password123!',
            role=role,
            mfa_enabled=False,
            is_locked=False,
            failed_login_count=0
        )
        db.add(u)
    else:
        u.employee_id = emp_id
        u.password_hash = 'Password123!'
        u.role = role
        u.mfa_enabled = False
        u.is_locked = False
        u.failed_login_count = 0
    db.commit()
    print(f'Configured user: {uname} -> Role: {role}')

upsert_user('kavindu', e_ceo.employee_id, 'ceo_admin')
upsert_user('dilshan', e_pm.employee_id, 'project_manager')
upsert_user('bimsari', e_dev.employee_id, 'developer_qa')
upsert_user('nimna', e_dev2.employee_id, 'developer_qa')
upsert_user('client', None, 'client')

print('All 5 core role users verified successfully!')
for u in db.query(AppUser).all():
    emp = db.query(Employee).filter(Employee.employee_id == u.employee_id).first() if u.employee_id else None
    emp_label = emp.full_name if emp else 'CarePlus Telehealth Client'
    print(f'  - Username: {u.username} | Role: {u.role} | Name: {emp_label} | MFA: {u.mfa_enabled}')

db.close()
