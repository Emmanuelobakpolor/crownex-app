import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/user_session.dart';
import '../theme/app_colors.dart';
import '../widgets/auto_convert_tile.dart';
import '../widgets/user_avatar.dart';
import 'change_transaction_pin_screen.dart';
import 'contact_support_screen.dart';
import 'help_center_screen.dart';
import 'legal_document_screen.dart';
import 'personal_information_screen.dart';
import 'sign_in_screen.dart';

/// Settings tab — account, support, and logout.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.fullName});

  final String fullName;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label coming soon'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmLogOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log out?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'You will need to sign in again to access your account.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Log out',
              style: TextStyle(
                color: Color(0xFFE53935),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await AuthService.instance.logout();
    if (!mounted) return;
    context.read<UserSession>().clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Consumer<UserSession>(
            builder: (context, session, _) {
              final user = session.user;
              return _ProfileCard(
                fullName: user?.fullName ?? widget.fullName,
                profilePictureUrl: user?.profilePicture,
                onEdit: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PersonalInformationScreen(),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
          _SettingsSection(
            title: 'Account',
            children: [
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                iconBg: const Color(0xFFE0E7FF),
                iconColor: const Color(0xFF4F6BED),
                label: 'Personal Information',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PersonalInformationScreen(),
                    ),
                  );
                },
              ),
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                iconBg: const Color(0xFFFFE0E0),
                iconColor: const Color(0xFFE53935),
                label: 'Security & Transaction PIN',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ChangeTransactionPinScreen(),
                    ),
                  );
                },
              ),
              _SettingsTile(
                icon: Icons.account_balance_outlined,
                iconBg: const Color(0xFFD4FBF6),
                iconColor: const Color(0xFF14B8A6),
                label: 'Linked Accounts & Cards',
                onTap: () => _comingSoon('Linked accounts'),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SettingsSection(
            title: 'Crypto',
            children: [AutoConvertTile()],
          ),
          const SizedBox(height: 20),
          _SettingsSection(
            title: 'Support',
            children: [
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                iconBg: const Color(0xFFD6F0FF),
                iconColor: const Color(0xFF2B9EDB),
                label: 'Help Center',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HelpCenterScreen(),
                    ),
                  );
                },
              ),
              _SettingsTile(
                icon: Icons.chat_bubble_outline_rounded,
                iconBg: const Color(0xFFCFF5E1),
                iconColor: const Color(0xFF1FAE63),
                label: 'Contact Support',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ContactSupportScreen(),
                    ),
                  );
                },
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SettingsSection(
            title: 'About',
            children: [
              _SettingsTile(
                icon: Icons.description_outlined,
                iconBg: const Color(0xFFE0E7FF),
                iconColor: const Color(0xFF4F6BED),
                label: 'Terms of Service',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TermsOfServiceScreen(),
                    ),
                  );
                },
              ),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                iconBg: const Color(0xFFFFE0E0),
                iconColor: const Color(0xFFE53935),
                label: 'Privacy Policy',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyPolicyScreen(),
                    ),
                  );
                },
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _LogOutButton(onTap: _confirmLogOut),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'Crownex v1.0.0',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.fullName,
    required this.onEdit,
    this.profilePictureUrl,
  });

  final String fullName;
  final VoidCallback onEdit;
  final String? profilePictureUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          UserAvatar(
            size: 54,
            profilePictureUrl: profilePictureUrl,
            fallbackName: fullName,
            borderWidth: 2.5,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'View and edit profile',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(18),
              bottom: isLast ? const Radius.circular(18) : Radius.zero,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 62, color: AppColors.border),
      ],
    );
  }
}
class _LogOutButton extends StatelessWidget {
  const _LogOutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFE0E0),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, size: 19, color: Color(0xFFE53935)),
              SizedBox(width: 8),
              Text(
                'Log Out',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE53935),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
