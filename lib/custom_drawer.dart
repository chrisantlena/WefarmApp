import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'tracker_page.dart';
import 'profile_page.dart';
import 'shop_page.dart';
import 'history_page.dart';
import 'experience_page.dart';
import 'settings_page.dart';
import 'login_screen.dart';
import '../models/user_provider.dart';

class CustomDrawer extends StatelessWidget {
  final bool isMainScreen;
  final int? currentIndex;

  const CustomDrawer({
    super.key,
    this.isMainScreen = false,
    this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    return Drawer(
      width: 280,
      child: SafeArea(
        child: Column(
          children: [
            // Header Profil (selalu ada)
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
              child: UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFFf5bd52)),
                accountName: Text(user?.name ?? "Guest",
                    style: const TextStyle(fontSize: 18)),
                accountEmail: Text(user?.email ?? "guest@example.com"),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            user.photoUrl!,
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.person,
                                  size: 40, color: Color(0xFFf5bd52));
                            },
                          ),
                        )
                      : Icon(Icons.person, size: 40, color: Color(0xFFf5bd52)),
                ),
              ),
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (!isMainScreen) ...[
                    _buildSectionTitle("MAIN NAVIGATION"),
                    _buildListTile(
                      icon: Icons.home,
                      title: "Home",
                      isSelected: currentIndex == 0,
                      onTap: () =>
                          _navigateTo(context, const HomeScreen(), true),
                    ),
                    _buildListTile(
                      icon: Icons.track_changes,
                      title: "Tracker",
                      isSelected: currentIndex == 1,
                      onTap: () =>
                          _navigateTo(context, const TrackerPage(), true),
                    ),
                    _buildListTile(
                      icon: Icons.shopping_cart,
                      title: "Shop",
                      isSelected: currentIndex == 2,
                      onTap: () => _navigateTo(context, const ShopPage(), true),
                    ),
                  ],
                  _buildSectionTitle("MENU"),
                  _buildListTile(
                    icon: Icons.history,
                    title: "History",
                    onTap: () => _navigateTo(
                        context, const HistoryPage(), !isMainScreen),
                  ),
                  _buildListTile(
                    icon: Icons.people,
                    title: "Experience",
                    onTap: () => _navigateTo(
                        context, const ExperiencePage(), !isMainScreen),
                  ),
                  _buildListTile(
                    icon: Icons.settings,
                    title: "Settings",
                    onTap: () => _navigateTo(
                        context, const SettingsPage(), !isMainScreen),
                  ),
                ],
              ),
            ),

            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? const Color(0xFFf5bd52) : Colors.black87),
      title: Text(title),
      selected: isSelected,
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text("Log Out", style: TextStyle(color: Colors.red)),
        onTap: () => _showLogoutConfirmation(context),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Out"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () {
              Provider.of<UserProvider>(context, listen: false).logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget page, bool replace) {
    Navigator.pop(context);
    if (replace) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      );
    }
  }
}
