# MedQueue

MedQueue is a hospital queue management and appointment booking system. Patients can browse doctors, book appointments, track their place in the queue in real time, and trigger an emergency SOS. Doctors can manage schedules, run their daily queue, and mark patients present. Admins get live queue oversight, user management, and analytics.

## Features

- **Role-based accounts** — Patient, Doctor, and Admin with JWT authentication (SimpleJWT)
- **Appointment booking** — browse doctors, view real-time slot availability, book, cancel, and reschedule
- **Virtual queue** — automatic queue registration on confirmed appointments, call-next flow, live position tracking, and wait-time estimates
- **Emergency SOS** — patient panic trigger with location, dispatch workflow, and audit trail
- **Notifications** — OTP via email/SMS (Brevo/Twilio), appointment reminders, queue alerts, and Firebase Realtime DB mirroring
- **Admin tools** — user management, live queue overview across doctors, schedules, and daily/aggregate reports
- **Chatbot** — patient-facing chat assistant

## Technology Stack

| Layer      | Technology                                      |
| ---------- | ----------------------------------------------- |
| Frontend   | Flutter (Dart, Material 3, Provider)            |
| Backend    | Django 6 + Django REST Framework                |
| Auth       | SimpleJWT (24h access token, rotating refresh) |
| Real-time  | Firebase Realtime DB (Admin SDK)                |
| Queue      | Celery + Celery Beat, Redis broker               |
| Database   | SQLite (dev) / PostgreSQL (prod)                 |
| Messaging  | Brevo (email/SMS OTP), Twilio (SMS), WhatsApp   |
| Docs       | drf-spectacular (Swagger / ReDoc)               |

Full details in [`APPENDIX.md`](APPENDIX.md).

## Repository Structure

```
MedQueue_Project/
├── Frontend/
│   └── MedQueue_Frontend/          # Flutter app
│       ├── lib/
│       │   ├── main.dart           # App entry point
│       │   ├── models/             # Domain data models
│       │   ├── screens/            # Auth, patient, doctor, admin, profile screens
│       │   ├── services/           # API clients and services
│       │   ├── utils/              # Constants, colors, token manager
│       │   └── widgets/            # Reusable UI components
│       └── pubspec.yaml
│
├── medqueue_backend/               # Django REST API
│   ├── medqueue_backend/           # Project config (settings, urls)
│   ├── base/                       # Core app (models, views, serializers, services)
│   ├── requirements.txt
│   └── API_DOCUMENTATION.md
│
├── scripts/                        # Helper scripts
└── APPENDIX.md                     # Detailed technical reference
```

## Prerequisites

- **Python** 3.10+ and `pip`
- **Flutter SDK** 3.x (Dart `^3.10.3`)
- **Android Studio / emulator** or a physical device (for mobile), or a browser (for web)
- Optional: Redis (for Celery tasks), Firebase project, Brevo/Twilio credentials

## Running the Backend

```bash
cd medqueue_backend

# create and activate a virtual environment
python -m venv venv
venv\Scripts\activate          # Windows   (macOS/Linux: source venv/bin/activate)

# install dependencies
pip install -r requirements.txt

# configure environment variables
# copy the sample .env into place and fill in your values
# (DJANGO_SECRET_KEY is the only hard requirement for local dev)

# apply migrations and seed demo data
python manage.py migrate
python manage.py seed_data      # optional: doctors, patients, schedules (password Earth@123)

# start the API server
python manage.py runserver
```

The API is served at `http://localhost:8000/api/v1/`.

Interactive docs:
- Swagger: `http://localhost:8000/api/docs/`
- ReDoc: `http://localhost:8000/api/redoc/`

## Running the Frontend

```bash
cd Frontend/MedQueue_Frontend

# install dependencies
flutter pub get

# run (pick your device)
flutter run
```

On Windows you can also double-click `run_app.bat`.

The app resolves the backend per platform:

| Platform | API base URL |
| -------- | ------------ |
| Web      | `http://localhost:8000/api/v1` |
| Android / physical device | `http://10.223.6.233:8000/api/v1` (edit `lib/utils/api_constants.dart` to match your machine) |

## Environment Variables

Create a `.env` file inside `medqueue_backend/medqueue_backend/` (gitignored):

| Variable              | Purpose                                       |
| --------------------- | --------------------------------------------- |
| `DJANGO_SECRET_KEY`   | Django signing key (a default is used in dev) |
| `BREVO_API_KEY`       | Brevo transactional email API key             |
| `BREVO_SENDER_EMAIL`  | Verified sender address for OTP emails        |
| `BREVO_SENDER_NAME`   | Sender display name (default "MedQueue")      |
| Firebase credentials  | Admin SDK service account / Realtime DB config|
| Twilio credentials    | SMS provider credentials                      |

If external credentials are absent, OTP sends are mocked (logged locally).

## Testing

```bash
# backend
cd medqueue_backend
python manage.py test base.tests     # or: pytest

# frontend
cd Frontend/MedQueue_Frontend
flutter test
```

## License

Private project. See the original authors for usage inquiries.