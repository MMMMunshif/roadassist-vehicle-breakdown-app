part of '../../app.dart';

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Appearance')),
    body: ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.mode,
      builder: (context, selectedMode, _) => ListView(
        padding: const EdgeInsets.all(RaSpace.xl),
        children: [
          Text(
            'Choose theme',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: RaSpace.xs),
          Text(
            'Use your device setting or choose a theme for RoadAssist.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: RaSpace.xl),
          Card(
            child: Column(
              children: ThemeMode.values.map((mode) {
                final (icon, label, description) = switch (mode) {
                  ThemeMode.system => (
                    Icons.settings_suggest_outlined,
                    'System default',
                    'Match your phone appearance',
                  ),
                  ThemeMode.light => (
                    Icons.light_mode_outlined,
                    'Light',
                    'Always use the light theme',
                  ),
                  ThemeMode.dark => (
                    Icons.dark_mode_outlined,
                    'Dark',
                    'Comfortable viewing at night',
                  ),
                };
                final selected = mode == selectedMode;
                return ListTile(
                  onTap: () => AppThemeController.setMode(mode),
                  leading: Icon(icon),
                  title: Text(label),
                  subtitle: Text(description),
                  trailing: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ),
  );
}
