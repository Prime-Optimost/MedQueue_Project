class AppDummyData {
  // Dummy Doctors
  static List<Map<String, dynamic>> get doctorsList => [
    {
      'id': '1',
      'name': 'Dr. Kwasi Mensah',
      'specialization': 'General Practice',
      'rating': 4.8,
      'experience': 8,
      'available': true,
      'bio': 'Experienced general practitioner with focus on preventive care',
      'nextAvailable': '2026-05-05 09:00 AM',
    },
    {
      'id': '2',
      'name': 'Dr. Ama Ofori',
      'specialization': 'Pediatrics',
      'rating': 4.9,
      'experience': 6,
      'available': true,
      'bio': 'Specialized in child healthcare and pediatric emergencies',
      'nextAvailable': '2026-05-05 02:00 PM',
    },
    {
      'id': '3',
      'name': 'Dr. Kofi Boateng',
      'specialization': 'Cardiology',
      'rating': 4.7,
      'experience': 12,
      'available': false,
      'bio': 'Expert cardiologist with 12 years of experience',
      'nextAvailable': '2026-05-06 10:00 AM',
    },
    {
      'id': '4',
      'name': 'Dr. Yaa Asante',
      'specialization': 'Dermatology',
      'rating': 4.6,
      'experience': 5,
      'available': true,
      'bio': 'Skin care specialist treating all dermatological conditions',
      'nextAvailable': '2026-05-05 11:00 AM',
    },
    {
      'id': '5',
      'name': 'Dr. Nana Darkwa',
      'specialization': 'Orthopedics',
      'rating': 4.5,
      'experience': 10,
      'available': true,
      'bio': 'Orthopedic surgeon specializing in joint and bone injuries',
      'nextAvailable': '2026-05-05 03:00 PM',
    },
  ];

  // Dummy Appointments
  static List<Map<String, dynamic>> get appointmentsList => [
    {
      'id': '1',
      'patientName': 'John Osei',
      'doctorName': 'Dr. Kwasi Mensah',
      'specialization': 'General Practice',
      'date': '2026-05-10',
      'time': '10:00 AM',
      'reason': 'General Checkup',
      'status': 'scheduled',
    },
    {
      'id': '2',
      'patientName': 'John Osei',
      'doctorName': 'Dr. Ama Ofori',
      'specialization': 'Pediatrics',
      'date': '2026-05-15',
      'time': '02:30 PM',
      'reason': 'Consultation',
      'status': 'scheduled',
    },
    {
      'id': '3',
      'patientName': 'John Osei',
      'doctorName': 'Dr. Yaa Asante',
      'specialization': 'Dermatology',
      'date': '2026-04-28',
      'time': '03:00 PM',
      'reason': 'Follow-up Visit',
      'status': 'completed',
    },
  ];

  // Dummy Queue entries
  static List<Map<String, dynamic>> get queueEntries => [
    {
      'id': '1',
      'queueNumber': 5,
      'patientName': 'Michael Asante',
      'doctorName': 'Dr. Kwasi Mensah',
      'estimatedWait': 15,
      'status': 'waiting',
    },
    {
      'id': '2',
      'queueNumber': 6,
      'patientName': 'Abena Owusu',
      'doctorName': 'Dr. Kwasi Mensah',
      'estimatedWait': 30,
      'status': 'waiting',
    },
    {
      'id': '3',
      'queueNumber': 7,
      'patientName': 'Efua Appiah',
      'doctorName': 'Dr. Ama Ofori',
      'estimatedWait': 20,
      'status': 'waiting',
    },
    {
      'id': '4',
      'queueNumber': 1,
      'patientName': 'Joseph Boakye',
      'doctorName': 'Dr. Kwasi Mensah',
      'estimatedWait': 0,
      'status': 'inProgress',
    },
  ];

  // Dummy Notifications
  static List<Map<String, dynamic>> get notificationsList => [
    {
      'id': '1',
      'title': 'Appointment Reminder',
      'message': 'Your appointment with Dr. Kwasi Mensah is tomorrow at 10:00 AM',
      'type': 'reminder',
      'read': false,
      'timestamp': '2 hours ago',
    },
    {
      'id': '2',
      'title': 'Queue Update',
      'message': 'You are now #5 in the queue. Estimated wait time: 15 minutes',
      'type': 'queue',
      'read': false,
      'timestamp': '30 minutes ago',
    },
    {
      'id': '3',
      'title': 'Appointment Confirmed',
      'message': 'Your appointment on May 10 at 10:00 AM has been confirmed',
      'type': 'appointment',
      'read': true,
      'timestamp': '1 day ago',
    },
  ];
}
