import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_exception.dart';
import '../../services/kyc_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth_widgets.dart';
import 'virtual_card_controller.dart';
import 'virtual_card_widgets.dart';

// ─── Verification hub ────────────────────────────────────────────────────────

class CardVerificationHubScreen extends StatefulWidget {
  const CardVerificationHubScreen({
    super.key,
    required this.controller,
  });

  final VirtualCardController controller;

  @override
  State<CardVerificationHubScreen> createState() =>
      _CardVerificationHubScreenState();
}

class _CardVerificationHubScreenState extends State<CardVerificationHubScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.syncFromBackend();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
          ),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CardFlowHeader(
                    title: 'Verification',
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Complete Required\nVerification Steps',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: kCardPurple,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Provide the necessary information to complete the\n'
                            'verification process to proceed with your card setup.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _StepTile(
                            icon: Icons.person_outline_rounded,
                            done: controller.personalDone,
                            pending: false,
                            title: 'Personal Information',
                            subtitle: controller.personalDone
                                ? 'Personal information confirmed'
                                : 'Input additional requirements',
                            onTap: () async {
                              final ok = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => PersonalInfoScreen(
                                    controller: controller,
                                  ),
                                ),
                              );
                              if (ok == true) controller.completePersonal();
                            },
                          ),
                          const SizedBox(height: 12),
                          _StepTile(
                            icon: Icons.badge_outlined,
                            done: controller.identityDone && controller.reviewSeen,
                            pending: controller.identityDone && !controller.reviewSeen,
                            title: 'Identity verification',
                            subtitle: controller.identityDone && controller.reviewSeen
                                ? 'Identity confirmed'
                                : controller.identityDone
                                ? 'Review pending...'
                                : 'Submit your valid ID document',
                            onTap: () async {
                              final ok = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => IdentityVerificationScreen(
                                    controller: controller,
                                  ),
                                ),
                              );
                              if (ok == true) controller.completeIdentity();
                            },
                          ),
                          const SizedBox(height: 12),
                          _StepTile(
                            icon: Icons.location_on_outlined,
                            done: controller.addressDone && controller.reviewSeen,
                            pending: controller.addressDone && !controller.reviewSeen,
                            title: 'Residential address',
                            subtitle: controller.addressDone && controller.reviewSeen
                                ? 'Address confirmed'
                                : controller.addressDone
                                ? 'Review pending...'
                                : 'Confirm your residential address',
                            onTap: () async {
                              final ok = await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => ResidentialAddressScreen(
                                    controller: controller,
                                  ),
                                ),
                              );
                              if (ok == true) {
                                controller.completeAddress();
                                if (controller.allVerificationDone &&
                                    context.mounted) {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => CardReviewPendingScreen(
                                        controller: controller,
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.done,
    required this.pending,
    this.icon,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool done;
  final bool pending;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              if (done)
                const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF16A34A),
                  size: 24,
                )
              else if (pending)
                const MiniHourglass(size: 24)
              else
                Icon(icon, color: AppColors.textPrimary, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: done || pending
                            ? AppColors.textSecondary
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Personal info ───────────────────────────────────────────────────────────

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key, required this.controller});

  final VirtualCardController controller;

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _dob = TextEditingController();
  String? _photoName;
  String? _photoPath;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    _dob.dispose();
    super.dispose();
  }

  bool get _valid =>
      _first.text.trim().isNotEmpty &&
      _last.text.trim().isNotEmpty &&
      _email.text.contains('@') &&
      _phone.text.trim().length >= 10 &&
      _dob.text.trim().isNotEmpty &&
      _photoPath != null;

  Future<void> _pickSelfie() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (file == null) return;
    setState(() {
      _photoPath = file.path;
      _photoName = file.name;
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 16),
    );
    if (picked != null) {
      setState(() {
        _dob.text =
            '${picked.day.toString().padLeft(2, '0')}/'
            '${picked.month.toString().padLeft(2, '0')}/'
            '${picked.year}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            CardFlowHeader(
              title: 'Verification',
              onBack: () => Navigator.of(context).pop(false),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personal Information',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: kCardPurple,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Please input additional required\ninformation to proceed',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const VerifyFieldLabel('First Name'),
                    VerifyTextField(
                      controller: _first,
                      hint: 'First name',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    const VerifyFieldLabel('Last Name'),
                    VerifyTextField(
                      controller: _last,
                      hint: 'Last name',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    const VerifyFieldLabel('Email'),
                    VerifyTextField(
                      controller: _email,
                      hint: 'email@example.com',
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    const VerifyFieldLabel('Phone Number'),
                    VerifyTextField(
                      controller: _phone,
                      hint: '08012345678',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    const VerifyFieldLabel('Date of Birth'),
                    VerifyTextField(
                      controller: _dob,
                      hint: 'DD/MM/YYYY',
                      readOnly: true,
                      onTap: _pickDob,
                      suffix: IconButton(
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          color: kCardPurple,
                          size: 20,
                        ),
                        onPressed: _pickDob,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const VerifyFieldLabel('Upload Photo'),
                    UploadBox(
                      label: 'Upload a clear photo of your face',
                      fileName: _photoName,
                      onTap: _pickSelfie,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
              child: VerifySubmitButton(
                enabled: _valid,
                onPressed: () {
                  widget.controller.completePersonal(
                    name: '${_first.text.trim()} ${_last.text.trim()}',
                    selfiePath: _photoPath,
                  );
                  Navigator.of(context).pop(true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Identity ────────────────────────────────────────────────────────────────

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key, required this.controller});

  final VirtualCardController controller;

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  String? _idType;
  final _idNumber = TextEditingController();
  String? _docName;
  String? _docPath;
  bool _submitting = false;
  String? _error;

  static const _idTypes = [
    ('International Passport', true),
    ('NIN', false),
    ("Driver's License", false),
    ('Voter\'s Card', false),
  ];

  // Dojah verification is currently wired up for NIN only (see
  // kyc/dojah.py) — other ID types can be added there and here together.
  static const _supportedBackendTypes = {'NIN': 'nin'};

  @override
  void dispose() {
    _idNumber.dispose();
    super.dispose();
  }

  bool get _valid =>
      _idType != null &&
      _idNumber.text.trim().length >= 5 &&
      _docPath != null &&
      !_submitting;

  Future<void> _pickDocument() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() {
      _docPath = file.path;
      _docName = file.name;
    });
  }

  Future<void> _submit() async {
    final idType = _idType;
    final selfiePath = widget.controller.selfiePath;
    if (idType == null) return;

    final backendType = _supportedBackendTypes[idType];
    if (backendType == null) {
      setState(() {
        _error = '$idType verification is not yet supported. Please choose NIN.';
      });
      return;
    }
    if (selfiePath == null) {
      setState(() {
        _error = 'Please complete Personal Information (with your selfie) first.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await KycService.instance.submitVerification(
        idType: backendType,
        idNumber: _idNumber.text.trim(),
        selfiePath: selfiePath,
        idDocumentPath: _docPath,
      );
      if (!mounted) return;
      widget.controller.completeIdentity();
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not submit verification. Please try again.';
      });
    }
  }

  Future<void> _pickIdType() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'ID Type',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ..._idTypes.map((item) {
                  return ListTile(
                    title: Text(
                      item.$1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: kCardPurple,
                      ),
                    ),
                    trailing: item.$2
                        ? const Text(
                            'Recommended',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          )
                        : null,
                    onTap: () => Navigator.of(ctx).pop(item.$1),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
    if (result != null) setState(() => _idType = result);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            CardFlowHeader(
              title: 'Verification',
              onBack: () => Navigator.of(context).pop(false),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Identity Verification',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: kCardPurple,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Please provide required your valid ID\n'
                      'information and Document to proceed',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const VerifyFieldLabel('ID Type'),
                    InkWell(
                      onTap: _pickIdType,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: kFieldFill,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _idType ?? 'Choose preferred option',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: _idType != null
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: _idType != null
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const VerifyFieldLabel('ID Number'),
                    VerifyTextField(
                      controller: _idNumber,
                      hint: 'Input valid ID number',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    const VerifyFieldLabel('ID Document'),
                    UploadBox(
                      label: 'Upload Valid ID document',
                      compact: true,
                      fileName: _docName,
                      icon: Icons.upload_rounded,
                      onTap: _pickDocument,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
              child: VerifySubmitButton(
                enabled: _valid,
                label: _submitting ? 'Submitting…' : 'Submit',
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Residential address ─────────────────────────────────────────────────────

class ResidentialAddressScreen extends StatefulWidget {
  const ResidentialAddressScreen({super.key, required this.controller});

  final VirtualCardController controller;

  @override
  State<ResidentialAddressScreen> createState() =>
      _ResidentialAddressScreenState();
}

class _ResidentialAddressScreenState extends State<ResidentialAddressScreen> {
  final _address = TextEditingController();
  final _house = TextEditingController();
  final _city = TextEditingController();
  final _zip = TextEditingController();
  String? _state;
  final String _country = 'Nigeria';

  static const _states = [
    'Abia',
    'Adamawa',
    'Akwa Ibom',
    'Anambra',
    'Bauchi',
    'Bayelsa',
    'Benue',
    'Borno',
    'Cross River',
    'Delta',
    'Ebonyi',
    'Edo',
    'Ekiti',
    'Enugu',
    'Gombe',
    'Imo',
    'Jigawa',
    'Kaduna',
    'Kano',
    'Katsina',
    'Kebbi',
    'Kogi',
    'Kwara',
    'Lagos',
    'Nasarawa',
    'Niger',
    'Ogun',
    'Ondo',
    'Osun',
    'Oyo',
    'Plateau',
    'Rivers',
    'Sokoto',
    'Taraba',
    'Yobe',
    'Zamfara',
    'FCT',
  ];

  @override
  void dispose() {
    _address.dispose();
    _house.dispose();
    _city.dispose();
    _zip.dispose();
    super.dispose();
  }

  bool get _valid =>
      _address.text.trim().isNotEmpty &&
      _house.text.trim().isNotEmpty &&
      _city.text.trim().isNotEmpty &&
      _state != null &&
      _zip.text.trim().isNotEmpty;

  Future<void> _pickState() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: _states
              .map(
                (s) => ListTile(
                  title: Text(s),
                  onTap: () => Navigator.of(ctx).pop(s),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (result != null) setState(() => _state = result);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            CardFlowHeader(
              title: 'Verification',
              onBack: () => Navigator.of(context).pop(false),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Residential address',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: kCardPurple,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Confirm your residential address',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const VerifyFieldLabel('Full address'),
                    VerifyTextField(
                      controller: _address,
                      hint: 'House No., Street Name, City, State',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    const VerifyFieldLabel('House number'),
                    VerifyTextField(
                      controller: _house,
                      hint: 'Input number',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    const VerifyFieldLabel('City'),
                    VerifyTextField(
                      controller: _city,
                      hint: 'Input City',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    const VerifyFieldLabel('State'),
                    InkWell(
                      onTap: _pickState,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: kFieldFill,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _state ?? 'Select State',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: _state != null
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: _state != null
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const VerifyFieldLabel('Country'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: kFieldBorder),
                      ),
                      child: Row(
                        children: [
                          const Text('🇳🇬  ', style: TextStyle(fontSize: 18)),
                          Expanded(
                            child: Text(
                              _country,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const VerifyFieldLabel('Zip Code'),
                    VerifyTextField(
                      controller: _zip,
                      hint: 'Input Zip Code',
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
              child: VerifySubmitButton(
                enabled: _valid,
                onPressed: () {
                  final composed =
                      '${_house.text.trim()} ${_address.text.trim()}, '
                      '${_city.text.trim()}, $_state, $_country ${_zip.text.trim()}';
                  widget.controller.completeAddress(address: composed);
                  Navigator.of(context).pop(true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Review pending ──────────────────────────────────────────────────────────

class CardReviewPendingScreen extends StatefulWidget {
  const CardReviewPendingScreen({super.key, required this.controller});

  final VirtualCardController controller;

  @override
  State<CardReviewPendingScreen> createState() => _CardReviewPendingScreenState();
}

class _CardReviewPendingScreenState extends State<CardReviewPendingScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.syncFromBackend();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final rejected = controller.kycRejected;

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 12 + bottom),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Icon(
                    rejected ? Icons.error_outline_rounded : Icons.hourglass_top_rounded,
                    size: 72,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    rejected ? 'Verification Failed' : 'Review Pending',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    rejected
                        ? 'We could not verify your identity. Please check your '
                              'details and try again.'
                        : 'Your request is under review. We will notify you once\n'
                              'the verification process is complete. Thank you for\n'
                              'your patience.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(flex: 3),
                  AuthPrimaryButton(
                    label: rejected ? 'Try again' : 'Go to cards',
                    onPressed: () {
                      if (rejected) {
                        Navigator.of(context).pop();
                        return;
                      }
                      controller.markReviewSeen();
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
