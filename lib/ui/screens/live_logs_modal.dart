import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/managers/vpn_manager.dart';
import '../../core/themes/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../widgets/glass_card.dart';

class LiveLogsModal extends StatelessWidget {
  const LiveLogsModal({super.key});

  Color _getLevelColor(String level) {
    switch (level.toUpperCase()) {
      case 'ERR':
        return AppColors.red;
      case 'WARN':
        return const Color(0xFFF59E0B);
      case 'BLOCK':
        return const Color(0xFFEC4899);
      case 'OK':
        return AppColors.accent;
      case 'INFO':
      default:
        return AppColors.primaryLight;
    }
  }

  void _exportLogs(BuildContext context, VpnManager vpn, AppStrings strings) {
    if (vpn.terminalLogs.isEmpty) return;
    final buffer = StringBuffer();
    for (final log in vpn.terminalLogs.reversed) {
      buffer.writeln("[${log['time']}] [${log['level']}] ${log['msg']}");
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.logsCopied),
        backgroundColor: AppColors.surfaceCardDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnManager>(context);
    final strings = AppStrings(vpn.isArabic);
    final logs = vpn.terminalLogs;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.terminal_rounded, color: AppColors.primaryLight, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.liveEventLogs,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action buttons (Export / Clear)
              Row(
                children: [
                  Text(
                    '${logs.length} / 500',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark, fontFamily: 'monospace'),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: logs.isEmpty ? null : () => _exportLogs(context, vpn, strings),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHover,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, size: 14, color: AppColors.accent),
                          const SizedBox(width: 4),
                          Text(
                            strings.exportLogs,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: logs.isEmpty ? null : () => vpn.clearLogs(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHover,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.delete_sweep_rounded, size: 14, color: AppColors.red),
                          const SizedBox(width: 4),
                          Text(
                            strings.clearLogs,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.red),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: AppColors.borderDark, height: 1),
              const SizedBox(height: 10),

              // Logs List
              Expanded(
                child: logs.isEmpty
                    ? Center(
                        child: Text(
                          strings.noLogsYet,
                          style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: logs.length,
                          itemBuilder: (ctx, idx) {
                            final item = logs[idx];
                            final levelColor = _getLevelColor(item['level'] ?? 'INFO');

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['time'] ?? '--:--:--',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.textSecondaryDark,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: levelColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: levelColor.withValues(alpha: 0.4), width: 0.5),
                                    ),
                                    child: Text(
                                      item['level'] ?? 'INFO',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: levelColor,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item['msg'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textPrimary,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
