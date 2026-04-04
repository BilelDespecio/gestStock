import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gest_stock/newVersion/menu/theme_controller.dart';
import 'package:gest_stock/newVersion/vendeur/constants.dart';

void showAppMenuSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AppMenuSheet(),
  );
}

class AppMenuSheet extends StatelessWidget {
  AppMenuSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          _buildHeader(context),
          const Divider(),
          _buildThemeToggle(context),
          _buildMenuItem(
            context,
            icon: Icons.description_outlined,
            title: "Conditions d'utilisation",
            onTap: () => _showPlaceholderDialog(context, "Conditions d'utilisation"),
          ),
          _buildMenuItem(
            context,
            icon: Icons.privacy_tip_outlined,
            title: "Politique de confidentialité",
            onTap: () => _showPlaceholderDialog(context, "Politique de confidentialité"),
          ),
          _buildMenuItem(
            context,
            icon: Icons.info_outline,
            title: "À propos",
            onTap: () => _showPlaceholderDialog(context, "À propos"),
          ),
          const SizedBox(height: 20),
          _buildLogoutButton(context),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.accentColor.withOpacity(0.1),
            child: Icon(Icons.person, color: AppColors.accentColor, size: 30),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.email?.split('@').first ?? "Utilisateur",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  user?.email ?? "Aucun email",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return SwitchListTile(
          title: const Text("Mode Sombre"),
          secondary: Icon(
            themeController.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            color: themeController.isDarkMode ? Colors.amber : Colors.blue,
          ),
          value: themeController.isDarkMode,
          activeColor: AppColors.accentColor,
          onChanged: (value) => themeController.toggleTheme(value),
        );
      },
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.secondaryTextColor),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          if (context.mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          }
        },
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text("Déconnexion", style: TextStyle(color: Colors.white, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.criticalColor,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _showPlaceholderDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text("Le contenu de cette section sera bientôt disponible. Merci de votre patience."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fermer")),
        ],
      ),
    );
  }
}
