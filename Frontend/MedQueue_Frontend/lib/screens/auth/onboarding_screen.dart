import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../widgets/custom_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildOnboardingPage(
                    icon: Icons.calendar_today,
                    title: 'Smart Appointments',
                    description: 'Book appointments with doctors online without long queues',
                    color: AppColors.primaryBlue,
                  ),
                  _buildOnboardingPage(
                    icon: Icons.line_weight,
                    title: 'Virtual Queue',
                    description: 'Join queues remotely and get real-time updates on your position',
                    color: AppColors.primaryGreen,
                  ),
                  _buildOnboardingPage(
                    icon: Icons.local_hospital_outlined,
                    title: 'Health Guidance',
                    description: 'Get instant first-aid advice and symptom information from our AI',
                    color: AppColors.warningOrange,
                  ),
                  _buildOnboardingPage(
                    icon: Icons.emergency,
                    title: 'Emergency Support',
                    description: 'One-tap SOS for emergencies with location sharing',
                    color: AppColors.emergencyRed,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Dots indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      4,
                      (index) => Container(
                        width: _currentPage == index ? 12 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? AppColors.primaryBlue
                              : AppColors.borderColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Buttons
                  if (_currentPage == 3)
                    Column(
                      children: [
                        CustomButton(
                          label: 'Get Started',
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed(
                              '/register',
                              arguments: {'role': 'patient'},
                            );
                          },
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlineCustomButton(
                            label: 'Skip',
                            onPressed: () {
                              Navigator.of(context).pushReplacementNamed(
                                '/register',
                                arguments: {'role': 'patient'},
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomButton(
                            label: 'Next',
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 60,
            color: color,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            description,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textGray,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
