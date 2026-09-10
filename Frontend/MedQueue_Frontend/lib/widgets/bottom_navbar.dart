import 'package:flutter/material.dart';

import 'package:medqueue_frontend/utils/app_colors.dart';

class ModernBottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onTap;
  final List<NavItem>? items;

  const ModernBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.items,
  });

  @override
  State<ModernBottomNavBar> createState() => _ModernBottomNavBarState();
}

class _ModernBottomNavBarState extends State<ModernBottomNavBar>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;

  late final List<NavItem> _items;

  @override
  @override
  void initState() {
    super.initState();
    _items = widget.items ?? const [
      NavItem(icon: Icons.home_rounded, label: 'Home'),
      NavItem(icon: Icons.calendar_month_rounded, label: 'Bookings'),
      NavItem(icon: Icons.chat_bubble_rounded, label: 'Chat'),
      NavItem(icon: Icons.person_rounded, label: 'Profile'),
    ];
    
    _controllers = List.generate(
      _items.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );
    _scaleAnimations = _controllers
        .map((c) => Tween<double>(begin: 1.0, end: 1.15).animate(
              CurvedAnimation(parent: c, curve: Curves.easeOutBack),
            ))
        .toList();

    _controllers[widget.selectedIndex].forward();
  }

  @override
  void didUpdateWidget(ModernBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _controllers[oldWidget.selectedIndex].reverse();
      _controllers[widget.selectedIndex].forward();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.borderColor.withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.12),
                blurRadius: 24,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppColors.shadowColor.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (index) {
              final isSelected = widget.selectedIndex == index;
              return GestureDetector(
                onTap: () => widget.onTap(index),
                behavior: HitTestBehavior.opaque,
                child: AnimatedBuilder(
                  animation: _scaleAnimations[index],
                  builder: (context, child) => Transform.scale(
                    scale: _scaleAnimations[index].value,
                    child: child,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSelected ? 18 : 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [
                                AppColors.primaryBlue,
                                AppColors.primaryGreen,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primaryBlue.withValues(alpha: 0.35),
                                blurRadius: 14,
                                spreadRadius: -2,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _items[index].icon,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textGray,
                          size: 22,
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOutCubic,
                          child: isSelected
                              ? Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Text(
                                    _items[index].label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class NavItem {
  final IconData icon;
  final String label;
  const NavItem({required this.icon, required this.label});
}