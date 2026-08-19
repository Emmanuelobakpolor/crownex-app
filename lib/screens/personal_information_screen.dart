import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/user_session.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/user_avatar.dart';
import 'change_password_screen.dart';

/// Account tab — edit name, phone number, and profile picture; also the
/// entry point into changing the account password.
class PersonalInformationScreen extends StatefulWidget {
  const PersonalInformationScreen({super.key});

  @override
  State<PersonalInformationScreen> createState() =>
      _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final _picker = ImagePicker();

  CrownexUser? _user;
  String? _pickedImagePath;
  bool _loadingProfile = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final cached = context.read<UserSession>().user;
    if (cached != null) {
      _applyUser(cached);
    }
    try {
      final fresh = await AuthService.instance.fetchProfile();
      if (!mounted) return;
      _applyUser(fresh);
      context.read<UserSession>().setUser(fresh);
    } on ApiException catch (e) {
      if (!mounted || cached != null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  void _applyUser(CrownexUser user) {
    setState(() {
      _user = user;
      _nameController.text = user.fullName;
      _phoneController.text = user.phone;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _pickedImagePath = picked.path);
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final nameChanged = _user == null || name != _user!.fullName;
    final phoneChanged = _user == null || phone != _user!.phone;

    if (!nameChanged && !phoneChanged && _pickedImagePath == null) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await AuthService.instance.updateProfile(
        fullName: nameChanged ? name : null,
        phone: phoneChanged ? phone : null,
        imagePath: _pickedImagePath,
      );
      if (!mounted) return;
      context.read<UserSession>().setUser(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildAvatarPreview() {
    const size = 96.0;
    if (_pickedImagePath != null) {
      final preview = kIsWeb
          ? Image.network(_pickedImagePath!, width: size, height: size, fit: BoxFit.cover)
          : Image.file(File(_pickedImagePath!), width: size, height: size, fit: BoxFit.cover);
      return ClipOval(child: SizedBox(width: size, height: size, child: preview));
    }
    return UserAvatar(
      size: size,
      profilePictureUrl: _user?.profilePicture,
      fallbackName: _nameController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              AuthAppHeader(
                showProgress: false,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: _loadingProfile
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AuthTitleBlock(
                                title: 'Personal Information',
                                subtitle: 'Update your name, phone number, and photo',
                              ),
                              const SizedBox(height: 28),
                              Center(
                                child: GestureDetector(
                                  onTap: _showImageSourceSheet,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      _buildAvatarPreview(),
                                      Positioned(
                                        right: -2,
                                        bottom: -2,
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.background,
                                              width: 2.5,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt_rounded,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 36),
                              const AuthFieldLabel('Full Name'),
                              AuthTextField(
                                controller: _nameController,
                                hintText: 'Enter your full name',
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter your full name';
                                  }
                                  if (value.trim().length < 2) {
                                    return 'Name is too short';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 22),
                              const AuthFieldLabel('Phone Number'),
                              AuthTextField(
                                controller: _phoneController,
                                hintText: '08000000000',
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.done,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(11),
                                ],
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter your phone number';
                                  }
                                  if (value.trim().length < 10) {
                                    return 'Enter a valid phone number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28),
                              AuthPrimaryButton(
                                label: 'Save changes',
                                loading: _saving,
                                onPressed: _save,
                              ),
                              const SizedBox(height: 20),
                              Material(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const ChangePasswordScreen(),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.lock_outline_rounded,
                                          size: 20,
                                          color: AppColors.textPrimary,
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text(
                                            'Change Password',
                                            style: TextStyle(
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
                              SizedBox(height: bottomPad),
                            ],
                          ),
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
