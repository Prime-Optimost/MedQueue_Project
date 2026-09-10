import 'package:medqueue_frontend/screens/profile/profile_edit_screen.dart';
import 'package:medqueue_frontend/utils/api_constants.dart';

class PatientEditProfileScreen extends ProfileEditScreen {
  const PatientEditProfileScreen({super.key}) : super(role: UserRole.patient);
}
