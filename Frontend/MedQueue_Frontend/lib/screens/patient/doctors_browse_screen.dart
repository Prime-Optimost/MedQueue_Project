import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/doctor_model.dart';
import '../../services/doctor_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_components.dart';
import '../../widgets/doctor_card.dart';

class DoctorsBrowseScreen extends StatefulWidget {
  const DoctorsBrowseScreen({super.key});

  @override
  State<DoctorsBrowseScreen> createState() => _DoctorsBrowseScreenState();
}

class _DoctorsBrowseScreenState extends State<DoctorsBrowseScreen> {
  final _searchController = TextEditingController();
  String _selectedSpecialization = '';
  List<String> specializations = [];
  bool _specializationsExtracted = false;

  @override
  void initState() {
    super.initState();
    // Fetch doctors on screen load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchDoctors();
      }
    });
  }

  void _fetchDoctors({String? search, String? specialization}) {
    final doctorService = context.read<DoctorService>();
    doctorService.fetchDoctors(
      name: search,
      specialization: specialization,
    );
  }

  void _extractSpecializations(List<Doctor> doctors) {
    final specs = <String>{};
    for (var doc in doctors) {
      specs.add(doc.specialization);
    }
    setState(() {
      specializations = specs.toList()..sort();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryBlue, AppColors.primaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Column(
          children: [
            const Text(
              'Browse Doctors',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3),
            ),
           
          ],
        ),
       
      ),
      body: Consumer<DoctorService>(
        builder: (context, doctorService, _) {
          // Extract specializations from available doctors (only once)
          if (!_specializationsExtracted && doctorService.doctors.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _extractSpecializations(doctorService.doctors);
              }
            });
            _specializationsExtracted = true;
          }

          if (doctorService.isLoading && doctorService.doctors.isEmpty) {
            return const CustomLoadingIndicator(
              message: 'Loading doctors...',
            );
          }

          if (doctorService.errorMessage != null &&
              doctorService.doctors.isEmpty) {
            return _buildErrorWidget(context, doctorService);
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search doctors by name...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      _fetchDoctors(
                        search: value,
                        specialization: _selectedSpecialization.isEmpty
                            ? null
                            : _selectedSpecialization,
                      );
                    },
                  ),
                ),
                // Specialization filter chips
                if (specializations.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Specialization',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: specializations.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: const Text('All'),
                                    selected: _selectedSpecialization.isEmpty,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedSpecialization = '';
                                      });
                                      _fetchDoctors(
                                        search: _searchController.text.isEmpty
                                            ? null
                                            : _searchController.text,
                                      );
                                    },
                                  ),
                                );
                              }
                              final spec = specializations[index - 1];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(spec),
                                  selected: _selectedSpecialization == spec,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedSpecialization =
                                          selected ? spec : '';
                                    });
                                    _fetchDoctors(
                                      search: _searchController.text.isEmpty
                                          ? null
                                          : _searchController.text,
                                      specialization: selected ? spec : null,
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                // Doctors list
                if (doctorService.doctors.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.people_outline,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text(
                            'No doctors found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Try adjusting your search or filters',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: doctorService.doctors.length,
                    itemBuilder: (context, index) {
                      final doctor = doctorService.doctors[index];
                      return DoctorCard(
                        doctor: doctor,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/patient/doctor-detail',
                            arguments: doctor.id,
                          );
                        },
                      );
                    },
                  ),
                if (doctorService.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: CustomLoadingIndicator(
                      message: 'Fetching doctors...',
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget(
    BuildContext context,
    DoctorService doctorService,
  ) {
    return AppErrorWidget(
      title: 'Failed to Load Doctors',
      message: doctorService.errorMessage ?? 'An error occurred',
      onRetry: _fetchDoctors,
    );
  }
}
