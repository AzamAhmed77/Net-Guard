import 'package:flutter/material.dart';
import '../../core/themes/app_colors.dart';
import '../../core/localization/app_strings.dart';

class BottomDockWidget extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onTabSelected;

  const BottomDockWidget({
    Key? key,
    required this.activeTab,
    required this.onTabSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    final tabs = [
      {'icon': Icons.home_rounded, 'label': s.tabHome},
      {'icon': Icons.shield_rounded, 'label': s.tabBlocker},
      {'icon': Icons.grid_view_rounded, 'label': s.tabApps},
      {'icon': Icons.pie_chart_rounded, 'label': s.tabUsage},
      {'icon': Icons.insights_rounded, 'label': s.tabHistory},
    ];

    return Container(
      margin: const EdgeInsets.only(left: 12, right: 12, bottom: 16, top: 4),
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.surfaceCardDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderDark, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(tabs.length, (index) {
          final isActive = activeTab == index;
          final item = tabs[index];
          return Expanded(
            flex: isActive ? 5 : 2,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTabSelected(index),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.symmetric(
                    horizontal: isActive ? 10 : 4,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.surfaceHover : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive ? AppColors.borderDark : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        size: 19,
                        color: isActive ? AppColors.accent : AppColors.textSecondary,
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item['label'] as String,
                              maxLines: 1,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
