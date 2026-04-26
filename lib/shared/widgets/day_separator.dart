import 'package:flutter/material.dart';
import 'package:merchanic_repair/shared/utils/date_formatter.dart';

/// Separador de día en el chat
class DaySeparator extends StatelessWidget {
  final DateTime date;

  const DaySeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          DateFormatter.formatDaySeparator(date),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      ),
    );
  }
}
