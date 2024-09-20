import 'package:flutter/material.dart';
import 'package:adaptive_theme/adaptive_theme.dart';

class ThemeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = AdaptiveTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Theme Selection'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select App Theme',
              style: Theme.of(context).textTheme.headlineMedium, // Use headlineMedium or other styles
            ),
            SizedBox(height: 16),
            ListTile(
              title: Text('System Default'),
              onTap: () {
                theme.setThemeMode(AdaptiveThemeMode.system);
              },
            ),
            ListTile(
              title: Text('Light Theme'),
              onTap: () {
                theme.setThemeMode(AdaptiveThemeMode.light);
              },
            ),
            ListTile(
              title: Text('Dark Theme'),
              onTap: () {
                theme.setThemeMode(AdaptiveThemeMode.dark);
              },
            ),
          ],
        ),
      ),
    );
  }
}
