import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/user_session.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';

/// Contact Support form — collects issue details for Crownex support.
class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();

  static const _topics = <String>[
    'Account & login',
    'Wallet deposit / withdraw',
    'Crypto deposit, swap or transfer',
    'Airtime, data or bills',
    'Gift cards',
    'Virtual card',
    'Security & PIN',
    'Fees & charges',
    'Other',
  ];

  String? _topic;
  bool _submitting = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserSession>().user;
    if (user != null && user.email.isNotEmpty) {
      _emailController.text = user.email;
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_topic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a topic.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    // Local confirmation flow until a support API endpoint is available.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _sent = true;
    });
  }

  void _resetForm() {
    setState(() {
      _sent = false;
      _topic = null;
      _subjectController.clear();
      _messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

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
                child: _sent
                    ? _SuccessView(onSendAnother: _resetForm)
                    : SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottom),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const AuthTitleBlock(
                                title: 'Contact Support',
                                subtitle:
                                    'Tell us what went wrong — we typically reply within 24 hours',
                              ),
                              const SizedBox(height: 18),
                              const _SupportHeroBanner(),
                              const SizedBox(height: 18),
                              const _QuickContactSection(),
                              const SizedBox(height: 22),
                              const AuthFieldLabel('Email'),
                              AuthTextField(
                                controller: _emailController,
                                hintText: 'you@email.com',
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  final value = v?.trim() ?? '';
                                  if (value.isEmpty) return 'Email is required';
                                  if (!value.contains('@') || !value.contains('.')) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              const AuthFieldLabel('Topic'),
                              _TopicPicker(
                                value: _topic,
                                topics: _topics,
                                onChanged: (v) => setState(() => _topic = v),
                              ),
                              const SizedBox(height: 16),
                              const AuthFieldLabel('Subject'),
                              AuthTextField(
                                controller: _subjectController,
                                hintText: 'Short summary of the issue',
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.sentences,
                                validator: (v) {
                                  if ((v?.trim() ?? '').length < 4) {
                                    return 'Please enter a subject';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              const AuthFieldLabel('Message'),
                              _MessageField(controller: _messageController),
                              const SizedBox(height: 10),
                              const Text(
                                'Include transaction IDs, wallet addresses, or meter numbers when relevant. Never share your password, OTP, or PIN.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 24),
                              AuthPrimaryButton(
                                label: 'Send message',
                                loading: _submitting,
                                onPressed: _submitting ? null : _submit,
                              ),
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

// ─── Contact constants ───────────────────────────────────────────────────────

class _SupportContacts {
  static const phoneDisplay = '0704 550 8115';
  static const phoneRaw = '07045508115';
  /// E.164 for Nigeria — used by WhatsApp / tel links.
  static const phoneE164 = '2347045508115';
  static const email = 'support@crownexapp.com';
  static const altEmail = 'Crownexnigeria@gmail.com';
  static const hours = 'Mon–Sun · 8am–10pm';
}

// ─── Launch helpers ──────────────────────────────────────────────────────────

Future<void> _launchUri(BuildContext context, Uri uri, {String? fallbackCopy}) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      if (fallbackCopy != null) {
        await Clipboard.setData(ClipboardData(text: fallbackCopy));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open app — $fallbackCopy copied'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open app'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  } catch (_) {
    if (!context.mounted) return;
    if (fallbackCopy != null) {
      await Clipboard.setData(ClipboardData(text: fallbackCopy));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open app — $fallbackCopy copied'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

Future<void> _openPhone(BuildContext context) async {
  final uri = Uri(scheme: 'tel', path: '+${_SupportContacts.phoneE164}');
  await _launchUri(context, uri, fallbackCopy: _SupportContacts.phoneRaw);
}

Future<void> _openWhatsApp(BuildContext context) async {
  final message = Uri.encodeComponent('Hi Crownex Support, I need help with…');
  final uri = Uri.parse(
    'https://wa.me/${_SupportContacts.phoneE164}?text=$message',
  );
  await _launchUri(context, uri, fallbackCopy: _SupportContacts.phoneRaw);
}

Future<void> _openEmail(BuildContext context, String email) async {
  final uri = Uri(
    scheme: 'mailto',
    path: email,
    queryParameters: {'subject': 'Crownex Support Request'},
  );
  await _launchUri(context, uri, fallbackCopy: email);
}

void _showPhoneOptions(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          16 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Contact by phone',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _SupportContacts.phoneDisplay,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            _SheetAction(
              icon: Icons.call_rounded,
              title: 'Call',
              subtitle: 'Open Phone app',
              onTap: () {
                Navigator.pop(ctx);
                _openPhone(context);
              },
            ),
            const SizedBox(height: 10),
            _SheetAction(
              icon: Icons.chat_rounded,
              title: 'WhatsApp',
              subtitle: 'Chat with support',
              onTap: () {
                Navigator.pop(ctx);
                _openWhatsApp(context);
              },
            ),
            const SizedBox(height: 10),
            _SheetAction(
              icon: Icons.content_copy_rounded,
              title: 'Copy number',
              subtitle: _SupportContacts.phoneRaw,
              onTap: () async {
                Navigator.pop(ctx);
                await Clipboard.setData(
                  const ClipboardData(text: _SupportContacts.phoneRaw),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Phone number copied'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

void _showEmailOptions(BuildContext context, String email, {required String label}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          16 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            _SheetAction(
              icon: Icons.mail_rounded,
              title: 'Open email app',
              subtitle: 'Gmail, Mail, Outlook…',
              onTap: () {
                Navigator.pop(ctx);
                _openEmail(context, email);
              },
            ),
            const SizedBox(height: 10),
            _SheetAction(
              icon: Icons.content_copy_rounded,
              title: 'Copy email',
              subtitle: email,
              onTap: () async {
                Navigator.pop(ctx);
                await Clipboard.setData(ClipboardData(text: email));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email copied'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.textPrimary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
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

// ─── Hero banner ─────────────────────────────────────────────────────────────

class _SupportHeroBanner extends StatelessWidget {
  const _SupportHeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 2, 28, 85),
            Color.fromARGB(255, 12, 74, 174),
            Color(0xFF6366F1),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 8, 39, 106).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We’re here to help',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Call, WhatsApp, or email — usually within 24 hours',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: Color(0xFFE0E7FF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick contact list (full-width rows — no clipped emails) ────────────────

class _QuickContactSection extends StatelessWidget {
  const _QuickContactSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reach us directly',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        _ContactTile(
          icon: Icons.call_rounded,
          title: 'Phone & WhatsApp',
          subtitle: _SupportContacts.phoneDisplay,
          actionLabel: 'Call or chat',
          onTap: () => _showPhoneOptions(context),
        ),
        const SizedBox(height: 10),
        _ContactTile(
          icon: Icons.mail_rounded,
          title: 'Email',
          subtitle: _SupportContacts.email,
          actionLabel: 'Send email',
          onTap: () => _showEmailOptions(
            context,
            _SupportContacts.email,
            label: 'Support email',
          ),
        ),
        const SizedBox(height: 10),
        _ContactTile(
          icon: Icons.alternate_email_rounded,
          title: 'Alt. email',
          subtitle: _SupportContacts.altEmail,
          actionLabel: 'Send email',
          onTap: () => _showEmailOptions(
            context,
            _SupportContacts.altEmail,
            label: 'Alternate email',
          ),
        ),
        const SizedBox(height: 10),
        const _HoursTile(),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.fieldFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      actionLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
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

class _HoursTile extends StatelessWidget {
  const _HoursTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.fieldFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Support hours',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  _SupportContacts.hours,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Nigeria time · Everyday',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Form widgets ────────────────────────────────────────────────────────────

class _TopicPicker extends StatelessWidget {
  const _TopicPicker({
    required this.value,
    required this.topics,
    required this.onChanged,
  });

  final String? value;
  final List<String> topics;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use — value is stable across Flutter SDKs in this project
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        hintText: 'Select a topic',
        hintStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.textMuted,
        ),
        filled: true,
        fillColor: AppColors.fieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
      items: topics
          .map(
            (t) => DropdownMenuItem<String>(
              value: t,
              child: Text(
                t,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _MessageField extends StatelessWidget {
  const _MessageField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      minLines: 5,
      maxLines: 8,
      maxLength: 1000,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.newline,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.4,
      ),
      validator: (v) {
        if ((v?.trim() ?? '').length < 20) {
          return 'Please describe the issue in a bit more detail';
        }
        return null;
      },
      decoration: InputDecoration(
        hintText: 'Describe your issue, including any error messages…',
        hintStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.textMuted,
        ),
        counterStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        filled: true,
        fillColor: AppColors.fieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.onSendAnother});

  final VoidCallback onSendAnother;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Color(0xFFCFF5E1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 44,
              color: Color(0xFF1FAE63),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Message sent',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Thanks for reaching out. Our team will review your request and reply to your email, usually within 24 hours.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          AuthPrimaryButton(
            label: 'Back to settings',
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onSendAnother,
            child: const Text(
              'Send another message',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}
