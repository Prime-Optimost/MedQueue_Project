# Appendix

Supplementary reference documentation for the MedQueue GH project.

---

## A. Technology Stack

| Layer      | Technology                          | Version / Notes                     |
| ---------- | ----------------------------------- | ----------------------------------- |
| Frontend   | Flutter (Dart)                      | SDK `^3.10.3`, Material 3           |
| Backend    | Python Django                       | Django `6.0.4`                      |
| API        | Django REST Framework               | DRF `3.17.1`                        |
| Auth       | SimpleJWT (djangorestframework-simplejwt) | `5.5.1`                       |
| Real-time  | Firebase (Admin SDK / Realtime DB)  | `firebase-admin 7.4.0`              |
| Queue      | Celery + Celery Beat                | `Celery 5.6.3` / `django-celery-beat` |
| Message broker | Redis                          | `redis 7.4.0` client                |
| Database   | SQLite (dev) / PostgreSQL (prod)    | `psycopg2-binary 2.9.12`            |
| OTP / Email| Brevo (Transactional Email + SMS)   | REST API                           |
| SMS        | Twilio                              | `twilio>=9.0.0`                     |
| Docs       | drf-spectacular (Swagger / ReDoc)   | `0.29.0`                            |

---

## B. Project Structure

```
MedQueue_Project/
├── Frontend/
│   └── MedQueue_Frontend/          # Flutter application
│       ├── lib/
│       │   ├── main.dart           # App entry point
│       │   ├── models/             # Domain data models (9 files)
│       │   ├── routes/             # Named route definitions
│       │   ├── screens/
│       │   │   ├── auth/           # Splash, onboarding, login, register, etc.
│       │   │   ├── patient/        # Booking, queue, SOS, chatbot, etc.
│       │   │   ├── doctor/         # Schedule, availability, queue management
│       │   │   ├── admin/          # User management, live queue, reports
│       │   │   └── profile/        # Shared profile editing
│       │   ├── services/           # API clients & business services
│       │   ├── utils/              # Constants, colors, token manager, helpers
│       │   └── widgets/            # Reusable UI components
│       ├── test/                   # Widget tests
│       ├── android/ ios/ web/ linux/ macos/ windows/
│       ├── run_app.bat             # Windows quick-start launcher
│       ├── pubspec.yaml
│       └── .env
│
├── medqueue_backend/               # Django project
│   ├── medqueue_backend/           # Project config (settings, urls, wsgi/asgi)
│   ├── base/                       # Core application
│   │   ├── views/                  # accounts, appointments, availability, queues, emergencies
│   │   ├── models.py               # All data models (single file)
│   │   ├── serializers.py          # DRF serializers
│   │   ├── services.py             # Business logic layer
│   │   ├── tasks.py                # Celery periodic/async tasks
│   │   ├── signals.py             # Appointment → Queue wiring
│   │   ├── permissions.py          # Role-based access controls
│   │   ├── urls.py                 # API route table
│   │   ├── admin.py, exceptions.py
│   │   ├── management/commands/    # seed_data, backfill_queue_entries
│   │   └── migrations/             # 0001–0008
│   ├── requirements.txt
│   ├── API_DOCUMENTATION.md        # Full API reference
│   ├── pytest.ini
│   └── .env                        # Environment secrets (gitignored)
│
├── media/profile_pictures/         # User-uploaded avatar images
├── scripts/                        # (standalone helper scripts)
└── db.sqlite3                      # Development database
```

---

## C. Data Model Reference

All models are declared in `medqueue_backend/base/models.py` (single-file module).

### C.1 Core Accounts

| Model              | Purpose                                             | Key fields                                                              |
| ------------------ | --------------------------------------------------- | ----------------------------------------------------------------------- |
| `User`             | Central auth model (extends `AbstractUser`)         | `role`, `phone_number`, `date_of_birth`, `gender`, `address`, `profile_picture`, `whatsapp_number`, `failed_login_attempts`, `lockout_until`, `notif_*` flags |
| `PatientProfile`   | 1:1 extension for patients                          | `blood_group`, `allergies`, `emergency_contact_name`, `emergency_contact_phone`, `medical_history` |
| `DoctorProfile`    | 1:1 extension for doctors                           | `specialization`, `medical_license_number`, `hospital_name`, `consultation_fee`, `years_of_experience`, `is_accepting_patients`, `bio`, `avg_consultation_minutes` |
| `OTPVerification`  | Short-lived one-time password record                | `purpose` (`phone_reg`, `password_reset`, `login_2fa`), `code`, `is_used`, `expires_at` |
| `AuditLog`         | Immutable security / compliance event log           | `event_type`, `ip_address`, `user_agent`, `metadata` (JSON), `created_at` |

### C.2 Appointments

| Model             | Purpose                                          | Key fields                                                                  |
| ----------------- | ------------------------------------------------ | --------------------------------------------------------------------------- |
| `DoctorSchedule`  | Recurring weekly availability per doctor         | `day_of_week` (0–6), `start_time`, `end_time`, `slot_duration_minutes`, `max_patients_per_day`, `is_active` |
| `TimeSlot`        | Concrete bookable slot for a date                | `doctor`, `date`, `start_time`, `end_time`, `status` (`available`, `booked`, `blocked`) |
| `Appointment`     | Core booking record                              | `patient`, `doctor`, `slot` (1:1), `status`, `reason`, `notes`, `rescheduled_from`, `cancelled_by`, `cancellation_reason`, `reminder_24h_sent`, `reminder_30m_sent` |

**Appointment statuses:** `pending` → `confirmed` → `completed` / `cancelled` / `no_show` / `rescheduled` (guarded by `VALID_TRANSITIONS`).

### C.3 Virtual Queue

| Model             | Purpose                                              | Key fields                                                          |
| ----------------- | ---------------------------------------------------- | ------------------------------------------------------------------- |
| `QueueSession`    | One queue per doctor per day (the "room")            | `status` (`active`, `paused`, `closed`), `current_position`, `next_number`, `pause_reason`, `total_pause_minutes` |
| `QueueEntry`      | One patient's place in a session (their "ticket")    | `queue_number`, `status` (`waiting`, `called`, `in_consult`, `completed`, `skipped`, `left`), `called_at`, `completed_at`, `notified_2away` |
| `QueuePauseLog`   | Immutable pause/resume audit record                  | `paused_at`, `resumed_at`, `reason`, `duration_minutes`              |

**Wait-time algorithm (FR-3.8):**

```
estimated_wait = positions_ahead × avg_consultation_minutes
```

`avg_consultation_minutes` is sourced from `DoctorProfile` and is intended to be refreshed nightly by a Celery task.

### C.4 Emergency SOS

| Model                 | Purpose                                              | Key fields                                                              |
| --------------------- | ---------------------------------------------------- | ----------------------------------------------------------------------- |
| `EmergencyContact`    | Hospital staff / numbers notified on SOS             | `contact_type` (`admin`, `ambulance`, `duty_doctor`, `emergency_line`), `phone_number`, `whatsapp_number`, `fcm_token`, `is_active` |
| `EmergencyRequest`    | Core SOS record                                      | `latitude`/`longitude`/`gps_accuracy_meters`, `emergency_type`, `status`, `confirmed_at`, `dispatched_at`, `resolved_at`, `response_time_seconds`, `handled_by`, `ambulance_plate`, `ambulance_eta_minutes` |
| `EmergencyStatusLog`  | Immutable status-change audit trail                  | `previous_status`, `new_status`, `changed_by`, `notes`                  |

**Emergency statuses:** `pending` → `dispatched` → `resolved` \| `cancelled` \| `false_alarm` (guarded by `VALID_STATUS_TRANSITIONS`).

---

## D. API Endpoint Catalog

Base URL: `http://localhost:8000/api/v1/`

### D.1 Authentication & Accounts

| Method | Endpoint                            | Access       | Purpose                              |
| ------ | ----------------------------------- | ------------ | ------------------------------------ |
| POST   | `/auth/register/`                   | Public       | Create account + send OTP            |
| POST   | `/auth/otp/send/`                   | Public       | Send / resend OTP                    |
| POST   | `/auth/otp/verify/`                 | Public       | Verify OTP → tokens                  |
| POST   | `/auth/otp/resend/`                 | Public       | Resend OTP                           |
| POST   | `/auth/login/`                      | Public       | Login (username/email/phone)         |
| POST   | `/auth/logout/`                     | Authenticated| Blacklist refresh token               |
| POST   | `/auth/token/refresh/`              | Authenticated| Rotate refresh → new access token    |
| POST   | `/auth/password/reset/request/`     | Public       | Send reset OTP                       |
| POST   | `/auth/password/reset/confirm/`     | Public       | Verify OTP + set new password        |
| GET    | `/auth/profile/`                    | Authenticated| Fetch own profile                    |
| PATCH  | `/auth/profile/`                    | Authenticated| Update own profile                   |
| GET    | `/auth/users/`                      | Admin        | List users (paginated, filterable)   |
| GET    | `/auth/users/<id>/`                 | Admin        | Fetch user                           |
| PATCH  | `/auth/users/<id>/`                 | Admin        | Update user                          |
| DELETE | `/auth/users/<id>/`                 | Admin        | Deactivate user                      |
| POST   | `/auth/admin/users/`                | Admin        | Create doctor/patient/admin account  |
| GET    | `/auth/admin/dashboard/stats/`      | Admin        | Dashboard overview stats             |

### D.2 Appointments

| Method | Endpoint                                     | Access       | Purpose                              |
| ------ | -------------------------------------------  | ------------ | ------------------------------------ |
| GET    | `/doctors/`                                  | Authenticated| Browse doctors                      |
| GET    | `/doctors/<doctor_id>/slots/?date=YYYY-MM-DD`| Authenticated| Real-time slot availability          |
| POST   | `/book/`                                     | Patient      | Book an appointment                  |
| GET    | `/history/`                                  | Patient      | Appointment history                  |
| GET    | `/doctor/schedule/?date=...&range=week`      | Doctor       | View my schedule                     |
| GET    | `/<pk>/`                                     | Authenticated| Appointment detail                   |
| POST   | `/<pk>/cancel/`                              | Patient/Admin| Cancel appointment (1h rule)         |
| POST   | `/<pk>/reschedule/`                          | Patient/Admin| Reschedule appointment               |
| POST   | `/<pk>/mark/`                                | Doctor       | Mark complete / no-show              |
| GET    | `/admin/schedules/`                          | Admin        | List/manage doctor schedules         |
| POST   | `/admin/schedules/`                          | Admin        | Create schedule                      |
| GET    | `/admin/schedules/<pk>/`                     | Admin        | Schedule detail                      |
| PATCH  | `/admin/schedules/<pk>/`                     | Admin        | Update schedule                      |
| DELETE | `/admin/schedules/<pk>/`                     | Admin        | Delete schedule                      |
| POST   | `/admin/override/`                           | Admin        | Override any appointment             |
| PATCH  | `/admin/override/<pk>/`                      | Admin        | Override appointment detail          |
| DELETE | `/admin/override/<pk>/`                      | Admin        | Delete override                      |

### D.3 Availability

| Method | Endpoint                       | Access | Purpose                       |
| ------ | ------------------------------ | ------ | ----------------------------- |
| GET    | `/availability/my/`            | Doctor | View my custom availability   |
| POST   | `/availability/my/`            | Doctor | Create availability           |
| PATCH  | `/availability/my/<pk>/`       | Doctor | Update availability           |
| DELETE | `/availability/my/<pk>/`       | Doctor | Delete availability           |

### D.4 Virtual Queue

| Method | Endpoint                                 | Access         | Purpose                              |
| ------ | ---------------------------------------- | -------------- | ------------------------------------ |
| GET    | `/my-position/?date=YYYY-MM-DD`          | Patient        | View own queue position             |
| POST   | `/leave/`                                | Patient        | Leave queue voluntarily              |
| GET    | `/doctor/?date=YYYY-MM-DD`               | Doctor         | View full day queue                  |
| POST   | `/doctor/call-next/`                     | Doctor         | Call next patient                    |
| POST   | `/doctor/entries/<entry_id>/complete/`   | Doctor         | Mark consultation complete           |
| POST   | `/doctor/pause/`                         | Doctor         | Pause queue                           |
| POST   | `/doctor/resume/`                        | Doctor         | Resume queue                          |
| POST   | `/doctor/close/`                         | Doctor         | Close queue                           |
| GET    | `/admin/overview/?date=YYYY-MM-DD`       | Admin          | Live queue overview (all doctors)     |
| GET    | `/admin/stats/daily/`                    | Admin          | Daily analytics                       |
| GET    | `/admin/stats/aggregate/`                | Admin          | Aggregate analytics                   |
| PATCH  | `/admin/entries/<entry_id>/`            | Admin          | Force-update any entry status         |

### D.5 Emergency SOS

| Method | Endpoint                             | Access         | Purpose                              |
| ------ | ------------------------------------ | -------------- | ------------------------------------ |
| POST   | `/sos/`                              | Patient        | Trigger SOS (with 5s countdown)      |
| GET    | `/sos/active/`                       | Patient        | View active SOS status               |
| POST   | `/sos/<pk>/cancel/`                  | Patient        | Cancel pending SOS                   |
| GET    | `/history/`                          | Patient        | SOS history                          |
| PATCH  | `/admin/<pk>/status/`                | Admin / Doctor | Update SOS status (dispatch, resolve)|
| GET    | `/admin/log/`                        | Admin          | Full emergency log                   |
| GET    | `/admin/<pk>/`                       | Admin          | Single SOS detail + timeline         |
| GET    | `/admin/summary/`                    | Admin          | Aggregate SOS summary stats          |
| GET    | `/admin/contacts/`                   | Admin          | List emergency contacts              |
| POST   | `/admin/contacts/`                   | Admin          | Create emergency contact             |
| GET    | `/admin/contacts/<pk>/`              | Admin          | Contact detail                       |
| PATCH  | `/admin/contacts/<pk>/`              | Admin          | Update contact                       |
| DELETE | `/admin/contacts/<pk>/`              | Admin          | Delete contact                       |

---

## E. Frontend Reference

### E.1 State Management & Dependencies

State management uses **Provider** (`provider: ^6.0.0`). The Flutter app also depends on:
`go_router`, `http`, `flutter_secure_storage`, `flutter_dotenv`, `intl`, `flutter_spinkit`, `uuid`, `google_fonts`, `flutter_markdown`, `url_launcher`, `image_picker`, `cupertino_icons`.

Dev dependencies: `flutter_lints`, `flutter_launcher_icons`.

### E.2 Services (lib/services/)

| Service                 | Responsibility                                           |
| ----------------------- | -------------------------------------------------------- |
| `api_client.dart`       | HTTP client with automatic token refresh + retry, multipart uploads |
| `auth_service.dart`     | Register / login / logout / OTP / password reset / state |
| `appointment_service.dart` | Appointment CRUD, booking, cancellation, rescheduling  |
| `doctor_service.dart`   | Doctor list, details, schedules                          |
| `availability_service.dart` | Doctor availability CRUD                              |
| `queue_service.dart` / `queue_api_service.dart` | Queue tracking, leave, status |
| `admin_service.dart`    | Admin user/schedule/report operations                    |
| `emergency_service.dart`| Emergency SOS trigger + status                          |
| `notification_service.dart` | Push/SMS/whatsapp notification handling              |
| `chatbot_service.dart`  | Patient chatbot integration                              |
| `whatsapp_service.dart` | WhatsApp link/integration helpers                       |

### E.3 Models (lib/models/)

`user_model`, `doctor_model`, `appointment_model`, `doctor_schedule_model`, `time_slot_model`, `queue_model`, `emergency_model`, `notification_model`, `chatbot_model`, `admin_dashboard_model`, `admin_reports_model`, `user_management_model`, `api_response_model`.

### E.4 Screen Map (lib/screens/)

| Area    | Screens                                                                                |
| ------- | ------------------------------------------------------------------------------------- |
| Auth    | Splash, Onboarding, Role Selection, Login, Register, Forgot Password, Startup Wrapper   |
| Patient | Home, Book Appointment, Booking Confirm, Appointment Detail, Appointment History, Queue Tracker, Doctors Browse, Doctor Detail, Chatbot, Emergency SOS, Notifications, Profile (edit) |
| Doctor  | Home (incl. queue dashboard), Appointments, Availability, Profile, Queue Management, Edit Profile |
| Admin   | Home, User Management (edit sheet), Live Queue, Add Doctor, Reports      |

### E.5 API Configuration (lib/utils/api_constants.dart)

- **Base URL** resolves per platform: web → `http://localhost:8000/api/v1`; Android/physical → `http://10.223.6.233:8000/api/v1`.
- Token storage keys: `access_token`, `refresh_token`, `user_data` (via `flutter_secure_storage`).
- Validation constants: OTP length `6`, expiry `5` min, max login attempts `3`, lockout `15` min, min password length `8`.

---

## F. Security Configuration

### F.1 JWT (SimpleJWT)

| Setting                  | Value                            |
| ------------------------ | -------------------------------- |
| Access token lifetime    | 24 hours                         |
| Refresh token lifetime   | 30 days                          |
| Rotate refresh tokens    | `True`                           |
| Blacklist after rotation | `True`                           |
| Update last login        | `True`                           |
| Auth header type         | `Bearer`                         |

### F.2 Account Lockout

- Trigger: **3** consecutive failed login attempts.
- Lockout duration: **15 minutes**.
- On successful login, the failure count and lockout are reset.
- Response includes the unlock time.

### F.3 OTP Policy

- 4–6 digit code (implementation uses 6-digit).
- Expiry: **5 minutes**.
- One active OTP per user per `purpose` (old codes are soft-invalidated on new generation).
- Rate limits enforced on send/verify endpoints.

### F.4 Role-Based Access Control (`base/permissions.py`)

| Permission class      | Allows                                  |
| --------------------- | --------------------------------------- |
| `IsPatient`           | `role == "patient"`                     |
| `IsDoctor`            | `role == "doctor"`                      |
| `IsAdminUser`         | `role == "admin"`                       |
| `IsDoctorOrAdmin`     | `role in {doctor, admin}`               |
| `IsOwnerOrAdmin`      | Object owner **or** admin (object level)|

### F.5 CORS

In development, CORS allows all origins and credentials (`CORS_ALLOW_ALL_ORIGINS = True`), intended to be locked down for production.

---

## G. Environment Variables

Loaded from `medqueue_backend/medqueue_backend/.env` (gitignored). Placeholder-driven values:

| Variable                | Purpose                                       |
| ----------------------- | --------------------------------------------- |
| `DJANGO_SECRET_KEY`     | Django signing key (default in dev)           |
| `BREVO_API_KEY`         | Brevo transactional email API key             |
| `BREVO_SENDER_EMAIL`    | Verified sender address for OTP emails        |
| `BREVO_SENDER_NAME`     | Sender display name (default "MedQueue")      |
| (Firebase credentials)  | Admin SDK service-account / Realtime DB config|
| (Twilio credentials)    | SMS provider credentials                      |

> **Note:** Routes/endpoints reference Firebase Realtime DB and Celery/Redis for production, but the current `settings.py` ships with SQLite and no Celery broker configured by default.

---

## H. Management Commands & Background Tasks

### H.1 Management Commands

| Command                            | Purpose                                              |
| ---------------------------------- | ---------------------------------------------------- |
| `python manage.py seed_data`       | Seed 10 doctors, 5 patients, and schedules (password `Earth@123`) |
| `python manage.py backfill_queue_entries` | Backfill queue entries for existing confirmed appointments |
| `python manage.py runserver`       | Run local development server                         |

### H.2 Celery Tasks (`base/tasks.py`)

| Task                          | Schedule (intended)   | Purpose                                        |
| ----------------------------- | --------------------- | ---------------------------------------------- |
| `send_appointment_reminders`  | every 5 min           | Send 24-hour and 30-minute reminders (FR-6.2) |
| `generate_daily_slots`        | midnight              | Pre-create slots for next N days              |
| `handle_no_show_followup`     | every 10 min          | Auto mark no-show / follow up after window     |

### H.3 Signals (`base/signals.py`)

- On `Appointment` save where status → `confirmed`, `QueueService.assign_queue_number()` runs automatically, creating a `QueueEntry` unless one already exists for that appointment.

---

## I. Testing

| Artifact           | Location / Command                                   |
| ------------------ | ---------------------------------------------------- |
| Backend tests      | `medqueue_backend/base/tests.py` (2,700+ lines, DRF `APIClient`) |
| Run backend tests  | `python manage.py test base.tests` or `pytest` (see `pytest.ini`) |
| Frontend tests     | `Frontend/MedQueue_Frontend/test/widget_test.dart`  |
| Run frontend tests | `flutter test`                                       |
| API docs           | Swagger `http://localhost:8000/api/docs/`, ReDoc `http://localhost:8000/api/redoc/`, OpenAPI `http://localhost:8000/api/schema/` |

---

## J. Common Workflows

### J.1 Development Setup (Backend)

```bash
cd medqueue_backend
pip install virtualenv
virtualenv venv                    # or `python -m venv venv`
venv\Scripts\activate              # Windows  (Linux/macOS: source venv/bin/activate)
pip install -r requirements.txt
python manage.py migrate
python manage.py seed_data         # optional demo data
python manage.py runserver
```

### J.2 Development Setup (Frontend)

```bash
cd Frontend/MedQueue_Frontend
flutter pub get
flutter run                        # or use run_app.bat on Windows
```

### J.3 End-to-End Auth Flow

1. `POST /auth/register/` → creates account + queues OTP.
2. `POST /auth/otp/verify/` → confirms phone, returns `access` + `refresh` tokens.
3. Use `Authorization: Bearer <access>` on protected endpoints.
4. On access-token expiry, `POST /auth/token/refresh/`.
5. `POST /auth/logout/` → blacklists the refresh token.

---

## K. Known Notes & Design Decisions

- **Model consolidation:** All models live in a single `base/models.py` with clear module-comment block separators (accounts, appointments, queue, emergency). Decorators/`on_delete` rules are documented inline.
- **Concurrency handling:** `SELECT FOR UPDATE` used in the booking service to prevent double-booking of a `TimeSlot`.
- **Cancellation model:** `Appointment.slot` is set to `NULL` on cancellation (freeing the slot) while the `Appointment` record itself is preserved for audit.
- **Rescheduling:** Creates a new `Appointment`; the old record is marked `rescheduled` and linked via `rescheduled_from`.
- **Queue pointer model:** The session holds a `current_position` pointer rather than mutating every entry, keeping state-change operations O(1) per advancement.
- **Firebase transport:** PostgreSQL (or SQLite in dev) is the source of truth; Firebase is a best-effort real-time mirror written *after* the DB commit.
- **OTP transport:** The server generates and verifies OTPs locally; Brevo/Twilio are dispatch-only transports. If credentials are absent, a mocked send is logged.

---

## L. Glossary

| Term                 | Meaning                                                        |
| -------------------- | -------------------------------------------------------------- |
| QueueEntry           | A patient's ticket / position record inside a QueueSession     |
| QueueSession         | The day's queue container for a single doctor                  |
| TimeSlot             | A discrete bookable window (e.g., 08:15–08:30) for a doctor    |
| FR-* / SRS           | Functional Requirement reference / Software Requirements Spec   |
| SOS                  | Emergency panic request (Module 5)                             |
| OTP                  | One-Time Password (registration / password-reset / 2FA)        |
| E.164                | International phone number format (e.g., `+233201234567`)      |
| GHS                  | Ghanaian Cedi (currency used for consultation fees)            |
| RBAC                 | Role-Based Access Control (`IsPatient`, `IsDoctor`, `IsAdmin`) |
| Drf-spectacular      | OpenAPI schema + Swagger/ReDoc generator for DRF               |
