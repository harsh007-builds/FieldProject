import 'package:flutter/material.dart';
import 'bmc_admin_dashboard.dart';
import 'building_admin_dashboard.dart';
import 'cleaner_dashboard.dart';

class RoleSelectorScreen extends StatelessWidget {
  const RoleSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                'System Gateway',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select your access portal',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 48),
              _buildRoleCard(
                context,
                title: 'BMC Admin',
                subtitle: 'Global analytics & system management',
                icon: Icons.admin_panel_settings,
                color: const Color(0xFF00FF94),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BmcAdminDashboard()),
                ),
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                context,
                title: 'Building Admin',
                subtitle: 'Localized analytics & complaints',
                icon: Icons.business,
                color: const Color(0xFF00D4FF),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BuildingAdminDashboard()),
                ),
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                context,
                title: 'Cleaner',
                subtitle: 'Waste logging & assigned tasks',
                icon: Icons.recycling,
                color: const Color(0xFFFF6B00),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CleanerDashboard()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color.withValues(alpha: 0.6), size: 20),
          ],
        ),
      ),
    );
  }
}
