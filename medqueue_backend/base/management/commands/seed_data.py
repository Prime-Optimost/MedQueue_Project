import random
from datetime import date, timedelta

from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone

from base.models import (
    User, UserRole, Gender, PatientProfile, DoctorProfile,
    DoctorSchedule,
)

DEFAULT_PASSWORD = "Earth@123"
NUM_DOCTORS = 10
NUM_PATIENTS = 5

DOCTOR_DATA = [
    {
        "first_name": "Kwame",
        "last_name": "Asante",
        "specialization": "General Practitioner",
        "hospital_name": "Korle Bu Teaching Hospital",
        "consultation_fee": 150.00,
        "years_of_experience": 12,
        "bio": "Experienced GP with a focus on preventive care and family medicine.",
    },
    {
        "first_name": "Akua",
        "last_name": "Mensah",
        "specialization": "Cardiologist",
        "hospital_name": "Komfo Anokye Teaching Hospital",
        "consultation_fee": 300.00,
        "years_of_experience": 15,
        "bio": "Specialist in cardiovascular diseases, hypertension, and heart failure management.",
    },
    {
        "first_name": "Yaw",
        "last_name": "Osei",
        "specialization": "Pediatrician",
        "hospital_name": "Ridge Hospital",
        "consultation_fee": 200.00,
        "years_of_experience": 9,
        "bio": "Passionate about children's health and developmental milestones.",
    },
    {
        "first_name": "Esi",
        "last_name": "Boateng",
        "specialization": "Dermatologist",
        "hospital_name": "DermaCare Clinic",
        "consultation_fee": 250.00,
        "years_of_experience": 10,
        "bio": "Treats skin, hair, and nail conditions with modern dermatological techniques.",
    },
    {
        "first_name": "Kofi",
        "last_name": "Adom",
        "specialization": "Orthopedic Surgeon",
        "hospital_name": "37 Military Hospital",
        "consultation_fee": 400.00,
        "years_of_experience": 18,
        "bio": "Specializes in joint replacements, fractures, and sports injuries.",
    },
    {
        "first_name": "Adwoa",
        "last_name": "Sarpong",
        "specialization": "Gynecologist",
        "hospital_name": "Korle Bu Teaching Hospital",
        "consultation_fee": 280.00,
        "years_of_experience": 14,
        "bio": "Provides comprehensive women's health services including prenatal care.",
    },
    {
        "first_name": "Nana",
        "last_name": "Agyeman",
        "specialization": "Neurologist",
        "hospital_name": "Neurology Specialists Ltd",
        "consultation_fee": 350.00,
        "years_of_experience": 16,
        "bio": "Expert in diagnosing and treating disorders of the brain and nervous system.",
    },
    {
        "first_name": "Abena",
        "last_name": "Owusu",
        "specialization": "Ophthalmologist",
        "hospital_name": "Ghana Eye Clinic",
        "consultation_fee": 220.00,
        "years_of_experience": 11,
        "bio": "Offers comprehensive eye care from routine exams to cataract surgery.",
    },
    {
        "first_name": "Kwesi",
        "last_name": "Tetteh",
        "specialization": "Dentist",
        "hospital_name": "Smile Dental Center",
        "consultation_fee": 180.00,
        "years_of_experience": 8,
        "bio": "Provides general dentistry, cosmetic procedures, and oral surgery.",
    },
    {
        "first_name": "Ama",
        "last_name": "Darko",
        "specialization": "Psychiatrist",
        "hospital_name": "Pantang Mental Health Hospital",
        "consultation_fee": 260.00,
        "years_of_experience": 13,
        "bio": "Dedicated to mental health and wellness, treating anxiety, depression, and more.",
    },
]

PATIENT_DATA = [
    {
        "first_name": "Kojo",
        "last_name": "Nyarko",
        "blood_group": "O+",
        "allergies": "Penicillin",
        "emergency_contact_name": "Adwoa Nyarko",
        "emergency_contact_phone": "+233201234568",
        "medical_history": "Asthma, seasonal allergies",
    },
    {
        "first_name": "Afi",
        "last_name": "Dzidzor",
        "blood_group": "A+",
        "allergies": "",
        "emergency_contact_name": "Kofi Dzidzor",
        "emergency_contact_phone": "+233201234569",
        "medical_history": "None",
    },
    {
        "first_name": "Ebow",
        "last_name": "Quarshie",
        "blood_group": "B+",
        "allergies": "Sulfa drugs",
        "emergency_contact_name": "Mama Quarshie",
        "emergency_contact_phone": "+233201234570",
        "medical_history": "Type 2 diabetes, hypertension",
    },
    {
        "first_name": "Baaba",
        "last_name": "Hagan",
        "blood_group": "AB+",
        "allergies": "Latex",
        "emergency_contact_name": "Papa Hagan",
        "emergency_contact_phone": "+233201234571",
        "medical_history": "Seasonal asthma",
    },
    {
        "first_name": "Sena",
        "last_name": "Agbo",
        "blood_group": "O-",
        "allergies": "Peanuts, shellfish",
        "emergency_contact_name": "Rose Agbo",
        "emergency_contact_phone": "+233201234572",
        "medical_history": "Eczema, hay fever",
    },
]

GENDERS = [Gender.MALE, Gender.FEMALE]
PHONE_PREFIXES = ["+23320", "+23324", "+23350", "+23355"]

# Days of the week for schedule generation (0=Mon .. 4=Fri)
DAYS = [0, 1, 2, 3, 4]


class Command(BaseCommand):
    help = "Seed the database with sample doctors and patients"

    def handle(self, *args, **options):
        self._seed_doctors()
        self._seed_patients()
        self.stdout.write(self.style.SUCCESS(
            f"Successfully seeded {NUM_DOCTORS} doctors and {NUM_PATIENTS} patients"
        ))

    def _create_user(self, first_name, last_name, role, gender=None):
        username = (f"{first_name.lower()}.{last_name.lower()}"
                    f"{random.randint(100, 999)}")
        email = f"{first_name.lower()}.{last_name.lower()}@medqueue.gh"
        phone = f"{random.choice(PHONE_PREFIXES)}{random.randint(1000000, 9999999)}"
        dob = date.today() - timedelta(
            days=random.randint(25, 60) * 365
        )
        user = User(
            username=username,
            email=email,
            first_name=first_name,
            last_name=last_name,
            role=role,
            phone_number=phone,
            gender=gender or random.choice(GENDERS),
            date_of_birth=dob,
            address=f"{random.randint(1, 999)} Sample Street, Accra",
            is_phone_verified=True,
            is_email_verified=True,
        )
        user.set_password(DEFAULT_PASSWORD)
        user.save()
        return user

    @transaction.atomic
    def _seed_doctors(self):
        gender_cycle = [Gender.MALE, Gender.FEMALE, Gender.MALE, Gender.FEMALE,
                        Gender.MALE, Gender.FEMALE, Gender.MALE, Gender.FEMALE,
                        Gender.MALE, Gender.FEMALE]
        for i, info in enumerate(DOCTOR_DATA):
            user = self._create_user(
                first_name=info["first_name"],
                last_name=info["last_name"],
                role=UserRole.DOCTOR,
                gender=gender_cycle[i],
            )
            DoctorProfile.objects.create(
                user=user,
                specialization=info["specialization"],
                medical_license_number=f"ML-{random.randint(10000, 99999)}-GH",
                hospital_name=info["hospital_name"],
                consultation_fee=info["consultation_fee"],
                years_of_experience=info["years_of_experience"],
                is_accepting_patients=True,
                bio=info["bio"],
                avg_consultation_minutes=random.choice([10, 15, 20, 30]),
            )
            self._create_doctor_schedule(user)
            self.stdout.write(f"  [OK] Doctor: {info['first_name']} {info['last_name']} ({info['specialization']})")

    def _create_doctor_schedule(self, doctor):
        for day in DAYS[:5]:
            start_hour = random.choice([8, 9])
            end_hour = start_hour + random.choice([8, 9])
            DoctorSchedule.objects.create(
                doctor=doctor,
                day_of_week=day,
                start_time=timezone.datetime.strptime(f"{start_hour}:00", "%H:%M").time(),
                end_time=timezone.datetime.strptime(f"{end_hour}:00", "%H:%M").time(),
                slot_duration_minutes=30,
                max_patients_per_day=random.randint(10, 20),
                is_active=True,
            )

    @transaction.atomic
    def _seed_patients(self):
        blood_groups = ["O+", "A+", "B+", "AB+", "O-", "A-", "B-", "AB-"]
        for info in PATIENT_DATA:
            gender = Gender.MALE if info["first_name"] in [
                "Kojo", "Ebow"
            ] else Gender.FEMALE
            user = self._create_user(
                first_name=info["first_name"],
                last_name=info["last_name"],
                role=UserRole.PATIENT,
                gender=gender,
            )
            PatientProfile.objects.create(
                user=user,
                blood_group=info["blood_group"],
                allergies=info["allergies"],
                emergency_contact_name=info["emergency_contact_name"],
                emergency_contact_phone=info["emergency_contact_phone"],
                medical_history=info["medical_history"],
            )
            self.stdout.write(f"  [OK] Patient: {info['first_name']} {info['last_name']}")
