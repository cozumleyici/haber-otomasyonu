import 'package:flutter/material.dart';

class PlatformSelector extends StatelessWidget {
  final List<String> selectedPlatforms;
  final ValueChanged<List<String>> onChanged;

  const PlatformSelector({
    Key? key,
    required this.selectedPlatforms,
    required this.onChanged,
  }) : super(key: key);

  void _togglePlatform(String platform, bool? isSelected) {
    final updated = List<String>.from(selectedPlatforms);
    if (isSelected == true) {
      if (!updated.contains(platform)) {
        updated.add(platform);
      }
    } else {
      updated.remove(platform);
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF383838) : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.share_rounded, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              const Text(
                'Publish Destinations',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Telegram Checkbox
              Expanded(
                child: InkWell(
                  onTap: () {
                    final current = selectedPlatforms.contains('telegram');
                    _togglePlatform('telegram', !current);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: selectedPlatforms.contains('telegram'),
                        activeColor: const Color(0xFF229ED9),
                        onChanged: (val) => _togglePlatform('telegram', val),
                      ),
                      const Icon(Icons.telegram, size: 20, color: Color(0xFF229ED9)),
                      const SizedBox(width: 6),
                      const Text('Telegram', style: TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),

              // WordPress Checkbox
              Expanded(
                child: InkWell(
                  onTap: () {
                    final current = selectedPlatforms.contains('wordpress');
                    _togglePlatform('wordpress', !current);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      Checkbox(
                        value: selectedPlatforms.contains('wordpress'),
                        activeColor: const Color(0xFF21759B),
                        onChanged: (val) => _togglePlatform('wordpress', val),
                      ),
                      const Icon(Icons.public, size: 20, color: Color(0xFF21759B)),
                      const SizedBox(width: 6),
                      const Text('WordPress', style: TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
