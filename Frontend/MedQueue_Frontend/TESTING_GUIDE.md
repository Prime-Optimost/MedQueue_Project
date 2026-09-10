# MedQueue GH - Testing & Demo Guide

## 🎬 Quick Start Demo

### Step 1: Run the Application
```bash
cd c:\Users\Felix\Documents\MedQueue_Frontend
flutter pub get
flutter run
```

### Step 2: Navigate Through the App

The app will start with a **Splash Screen**, followed by the **Onboarding** screens introducing key features.

## 📋 Demo Credentials & Test Scenarios

### Login Options
The app accepts any email/password combination, but will assign different roles based on the email:

| Email Pattern | Role | Destination |
|---|---|---|
| Contains "doctor" | Doctor | Doctor Dashboard |
| Contains "admin" | Admin | Admin Dashboard |
| Any other | Patient | Patient Dashboard |

**Examples:**
- `patient@gmail.com` / `password123` → Patient Dashboard
- `doctor.kwasi@gmail.com` / `password123` → Doctor Dashboard  
- `admin@hospital.com` / `password123` → Admin Dashboard

### Registration
- Create a new account with any valid email/password (6+ chars)
- Select role during registration
- Will log in automatically after registration

## 🧪 Feature Testing Guide

### 1. PATIENT FEATURES

#### Dashboard (Tab: Home)
- **Quick Actions**: 4 cards for main features
  - Book Appointment → Leads to booking flow
  - Queue Status → Shows virtual queue
  - AI Chatbot → Health assistant
  - Emergency SOS → Emergency help
- **Upcoming Appointments**: Shows booked appointments

#### Book Appointment (Screen)
1. Select a doctor from the list
2. Pick an appointment date (up to 30 days ahead)
3. Choose a time slot (9:00 AM - 4:30 PM)
4. Select reason for visit
5. Confirm booking
6. Success dialog appears

**Mock Doctors Available:**
- Dr. Kwasi Mensah (General Practice) - 4.8★
- Dr. Ama Ofori (Pediatrics) - 4.9★
- Dr. Kofi Boateng (Cardiology) - 4.7★ (Unavailable)
- Dr. Yaa Asante (Dermatology) - 4.6★
- Dr. Nana Darkwa (Orthopedics) - 4.5★

#### Appointments Tab
- **Upcoming**: Shows scheduled appointments with reschedule/cancel options
- **History**: Shows past and completed appointments

#### Queue Tracker
- Shows current position in queue
- Displays queue number with large badge
- Shows doctor name, wait time, and positions ahead
- Lists all current queue entries

#### Chatbot
- Start with welcome screen
- Ask about symptoms: "headache", "fever", "cold"
- Get educational responses with disclaimers
- Can also ask freeform questions (will get default response)

**Try these queries:**
- "I have a headache"
- "I have a fever"
- "What about cold?"
- Any other text for general response

#### Emergency SOS
- Shows emergency indicators
- Requires description of emergency
- Option to share location
- Submit request
- Success screen with follow-up instructions

#### Notifications
- Shows all notifications with types: appointment, queue, emergency, reminder
- Swipe to dismiss
- Click to mark as read

#### Profile (Tab)
- View personal information
- Edit Profile button (placeholder)
- Logout button

### 2. DOCTOR FEATURES

#### Home Tab
- Welcome banner with doctor name
- Today's summary stats:
  - 12 Patients Today
  - 8 Completed
  - 4 Waiting
  - Current Rating

#### Schedule Tab
- View today's schedule
- 12 appointments listed

#### Queue Tab
- List of patients in queue
- Queue number badge
- Patient name and status
- "Mark as Completed" button for each patient
- Click to remove from queue

#### Profile Tab
- Doctor information display
- Logout button

### 3. ADMIN FEATURES

#### Home Tab
- System overview with 4 metrics:
  - Total Users: 456
  - Doctors: 28
  - Appointments: 892
  - Emergencies: 12
- Quick action buttons:
  - Generate Reports
  - View Live Queue

#### Emergency Tab
- List of emergency requests
- Shows patient name, description, status
- Only active emergencies have "Acknowledge" button
- Click to acknowledge emergency

#### Users Tab
- Shows user statistics
- 456 total users
- 28 doctors
- 428 patients

#### Profile Tab
- Admin information
- Logout button

## 🔐 Authentication Flow Testing

1. **Splash Screen**: 3-second splash with app logo
2. **Onboarding**: 4 pages with feature introduction
   - Swipe or use Next/Skip buttons
   - Final page has "Get Started" button
3. **Role Selection**: Choose Patient, Doctor, or Admin
4. **Login**: Enter email and password
5. **Register**: Create new account (appears from login screen link)
6. **Forgot Password**: Reset password flow

## ⚡ Testing Tips

### Mock Delays
- All services have 1-2 second delays to simulate network calls
- Watch for loading spinners

### Error Handling
- Leave email empty: "Email is required"
- Invalid email format: "Invalid email format"
- Password < 6 chars: "Password must be at least 6 characters"
- Mismatched passwords on register: "Passwords do not match"

### Loading States
- Buttons show loading spinner during operations
- "isLoading" state prevents duplicate submissions

### Navigation
- Back button on header returns to previous screen
- Bottom navigation for main tabs
- Deep linking via named routes

## 📊 Data Persistence Notes

**IMPORTANT**: All data is volatile and resets on app restart because it's using mock services.

Mock data includes:
- 5 sample doctors with ratings
- 3 sample appointments
- 4 sample queue entries
- 3 sample notifications
- AI chatbot responses (hardcoded)

## 🎯 Testing Checklist

- [ ] Splash/Onboarding loads properly
- [ ] Can login with any email/password
- [ ] Role-based navigation works
- [ ] Patient can book appointment
- [ ] Appointment appears in history
- [ ] Queue tracker shows position
- [ ] Chatbot responds to queries
- [ ] Emergency SOS submission works
- [ ] Notifications display correctly
- [ ] Doctor queue management works
- [ ] Admin emergency management works
- [ ] Logout returns to splash screen
- [ ] All UI is responsive and well-formatted
- [ ] No crashes or errors during testing

## 🚀 Performance Testing

- Launch time: ~3-5 seconds (with splash screen)
- Navigation transitions: Smooth animations
- Scrolling: Performant even with long lists
- Memory: No noticeable leaks
- Mock API calls: Instant responses (after delay)

## 📱 Device Testing

Recommended testing on:
- Android emulator (Pixel 4/5)
- iOS simulator (iPhone 12/13)
- Physical device if available

## 🐛 Known Issues & Limitations

1. **Data is not persistent** - Everything resets on app restart
2. **No real backend** - All operations are mocked
3. **No location services** - GPS is faked with Kumasi, Ghana coordinates
4. **No image uploads** - Avatar is placeholder only
5. **No file downloads** - Reports are not actually generated
6. **No payment** - No integration with payment systems

## 💡 Pro Tips

1. **Test role-based access**: Use different email patterns
2. **Check error handling**: Try edge cases (empty fields, special characters)
3. **Observe animations**: Smooth transitions between screens
4. **Monitor loading states**: All async operations show feedback
5. **Test all tabs**: Each role has different tabs and features

## 📝 Demo Script (5-minute overview)

1. **(20 sec)** Show splash screen and onboarding
2. **(30 sec)** Login as patient, show home dashboard
3. **(45 sec)** Book appointment - select doctor, date, time, reason
4. **(30 sec)** Show queue tracker with live updates
5. **(30 sec)** Test chatbot with "fever" query
6. **(20 sec)** Show emergency SOS form
7. **(20 sec)** Show doctor dashboard and queue management
8. **(20 sec)** Show admin dashboard with emergency management
9. **(5 sec)** Logout and return to splash

---

**Ready to demo!** The app is fully functional for demonstration purposes. 🚀
