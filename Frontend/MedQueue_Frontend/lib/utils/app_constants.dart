class AppConstants {
  // App Info
  static const String appName = 'MedQueue GH';
  static const String appVersion = '1.0.0';
  
  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration mockDelay = Duration(seconds: 2);
  
  // Appointment
  static const int appointmentBookingDaysAhead = 30;
  static const List<String> appointmentReasons = [
    'General Checkup',
    'Follow-up Visit',
    'Consultation',
    'Lab Tests',
    'Vaccination',
    'Emergency',
    'Other',
  ];
  
  // Queue
  static const int averageConsultationTime = 15; // minutes
  static const int maxPatientsPerDoctor = 20;
  
  // Emergency SOS
  static const String emergencySOS = 'Emergency SOS';
  static const String requestHelp = 'Request Help';
  
  // Time slots for appointments
  static const List<String> timeSlots = [
    '09:00 AM',
    '09:30 AM',
    '10:00 AM',
    '10:30 AM',
    '11:00 AM',
    '11:30 AM',
    '02:00 PM',
    '02:30 PM',
    '03:00 PM',
    '03:30 PM',
    '04:00 PM',
    '04:30 PM',
  ];
  
  // Departments/Specializations
  static const List<String> specializations = [
    'General Practice',
    'Cardiology',
    'Pediatrics',
    'Orthopedics',
    'Dermatology',
    'Neurology',
    'Dentistry',
    'Ophthalmology',
  ];
}

class AppStrings {
  // General
  static const String appName = 'MedQueue GH';
  static const String loading = 'Loading...';
  static const String error = 'Error';
  static const String success = 'Success';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String back = 'Back';
  
  // Auth
  static const String login = 'Login';
  static const String register = 'Register';
  static const String logout = 'Logout';
  static const String forgotPassword = 'Forgot Password?';
  static const String createAccount = 'Create Account';
  static const String dontHaveAccount = "Don't have an account?";
  static const String alreadyHaveAccount = 'Already have an account?';
  static const String selectRole = 'Select Your Role';
  static const String continueAsPatient = 'Continue as Patient';
  static const String continueAsDoctor = 'Continue as Doctor';
  static const String continueAsAdmin = 'Continue as Admin';
  
  // Patient
  static const String bookAppointment = 'Book Appointment';
  static const String myAppointments = 'My Appointments';
  static const String queueStatus = 'Queue Status';
  static const String appointmentHistory = 'Appointment History';
  static const String doctorsList = 'Doctors';
  static const String selectDoctor = 'Select Doctor';
  static const String selectDate = 'Select Date';
  static const String selectTime = 'Select Time';
  static const String appointmentReason = 'Reason for Visit';
  
  // Doctor
  static const String dailySchedule = 'Daily Schedule';
  static const String queueManagement = 'Queue Management';
  static const String availabilitySettings = 'Availability Settings';
  static const String startConsultation = 'Start Consultation';
  static const String markAsCompleted = 'Mark as Completed';
  
  // Admin
  static const String manageUsers = 'Manage Users';
  static const String manageDoctors = 'Manage Doctors';
  static const String manageSchedules = 'Manage Schedules';
  static const String liveQueue = 'Live Queue';
  static const String emergencyRequests = 'Emergency Requests';
  static const String reports = 'Reports';
  
  // Emergency
  static const String emergencySOS = 'Emergency SOS';
  static const String requestHelp = 'Request Help';
  static const String shareLocation = 'Share My Location';
  static const String callAmbulance = 'Call Ambulance';
}
