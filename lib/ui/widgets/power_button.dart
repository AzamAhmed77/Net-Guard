import 'package:flutter/material.dart';
import '../../core/themes/app_colors.dart';
import '../../core/localization/app_strings.dart';

class PowerButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onToggle;

  const PowerButton({
    super.key,
    required this.isActive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final activeColor = isActive ? AppColors.green : AppColors.primary;
    final bgColor = isActive
        ? const Color(0xFF031A0C)
        : const Color(0xFF0A0714);

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: 140,
        height: 140,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // حلقات التوهج الخارجية بحجم أنيق ومتناسق وثابت بدون استهلاك بطارية
            if (isActive) ...[
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
              ),
              Container(
                width: 146,
                height: 146,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.green.withValues(alpha: 0.12),
                    width: 1.0,
                  ),
                ),
              ),
            ],
            // الزر الرئيسي المصغر والمريح للعين
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 114,
              height: 114,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
                border: Border.all(
                  color: activeColor,
                  width: isActive ? 2.5 : 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: isActive ? 0.35 : 0.12),
                    blurRadius: isActive ? 20 : 8,
                    spreadRadius: isActive ? 2 : 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.power_settings_new_rounded,
                    size: 38,
                    color: activeColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isActive
                        ? (s.isAr ? '🛡️ محمي' : '🛡️ Protected')
                        : (s.isAr ? '⚪ متوقف' : '⚪ Stopped'),
                    style: TextStyle(
                      color: activeColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    isActive
                        ? (s.isAr ? 'نشط' : 'Active')
                        : (s.isAr ? 'اضغط للتشغيل' : 'Tap to Start'),
                    style: TextStyle(
                      color: activeColor.withValues(alpha: 0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
