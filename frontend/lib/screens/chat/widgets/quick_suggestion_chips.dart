import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class QuickSuggestionChips extends StatelessWidget {
  final Function(String) onSelectSuggestion;

  const QuickSuggestionChips({
    super.key,
    required this.onSelectSuggestion,
  });

  static const List<Map<String, String>> suggestions = [
    {'label': '☕ Kopi 25rb', 'text': 'Kopi americano 25rb'},
    {'label': '🍛 Makan 28rb', 'text': 'Makan siang padang 28rb'},
    {'label': '⛽ Bensin 40rb', 'text': 'Beli bensin pertamax 40rb'},
    {'label': '🛒 Belanja 150rb', 'text': 'Belanja bulanan minimarket 150rb'},
    {'label': '💰 Gajian 5jt', 'text': 'Gajian bulanan 5jt'},
    {'label': '💼 Freelance 1.2jt', 'text': 'Terima freelance desain 1.2jt'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = suggestions[index];
          return ActionChip(
            label: Text(
              item['label']!,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: Colors.white,
            side: const BorderSide(color: AppTheme.borderSubtle),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
            onPressed: () => onSelectSuggestion(item['text']!),
          );
        },
      ),
    );
  }
}
