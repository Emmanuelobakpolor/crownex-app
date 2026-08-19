import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/user_session.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth_widgets.dart';
import 'card_creation_screens.dart';
import 'verification_screens.dart';
import 'virtual_card_controller.dart';
import 'virtual_card_widgets.dart';

/// Virtual Card bottom-nav tab — intro → pending → approved → active.
///
/// Rehydrates the controller's local flags from the real backend on every
/// entry to this tab — without this, a fresh VirtualCardController (e.g.
/// after an app restart) shows phase=pending forever even when KYC was
/// actually approved and/or a card already exists, since personalDone/
/// identityDone/addressDone/reviewSeen otherwise only ever get set by
/// walking through the verification sub-screens in the same session.
class VirtualCardTab extends StatefulWidget {
  const VirtualCardTab({super.key, required this.controller, this.onClose});

  final VirtualCardController controller;
  final VoidCallback? onClose;

  @override
  State<VirtualCardTab> createState() => _VirtualCardTabState();
}

class _VirtualCardTabState extends State<VirtualCardTab> {
  @override
  void initState() {
    super.initState();
    widget.controller.syncFromBackend();
    widget.controller.syncCardFromBackend();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        switch (widget.controller.phase) {
          case VirtualCardPhase.active:
            return CardDashboard(controller: widget.controller);
          case VirtualCardPhase.approved:
            return _ApprovedView(controller: widget.controller);
          case VirtualCardPhase.pending:
            return _PendingView(controller: widget.controller);
          case VirtualCardPhase.intro:
            return _IntroView(controller: widget.controller, onClose: widget.onClose);
        }
      },
    );
  }
}

// ─── Intro / request ─────────────────────────────────────────────────────────

class _IntroView extends StatelessWidget {
  const _IntroView({required this.controller, this.onClose});

  final VirtualCardController controller;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Text(
                  'Cards',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const VirtualCardVisual(last4: '78', angled: true),
                const SizedBox(height: 36),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Get your prepaid\ndebit card instantly!',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ...const [
                        'Faster international payment',
                        'Globally Accepted',
                        'Works on all your favorite stores',
                        'Heavily Secured',
                      ].map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            t,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 12 + bottom),
          child: AuthPrimaryButton(
            label: 'Request Virtual Card',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      CardVerificationHubScreen(controller: controller),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Pending review ──────────────────────────────────────────────────────────

class _PendingView extends StatelessWidget {
  const _PendingView({required this.controller});

  final VirtualCardController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Cards',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 20),
          const VirtualCardVisual(last4: '78', angled: true),
          const SizedBox(height: 28),
          const Text(
            'Card Request Pending',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            "Your details are under review. We'll notify you once\n"
            "it's complete and you can create your virtual card.",
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 22),
          _PendingStep(
            done: controller.personalDone,
            pending: !controller.personalDone,
            title: 'Personal Information',
            subtitle: controller.personalDone
                ? 'Personal information confirmed'
                : 'Review pending...',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      CardVerificationHubScreen(controller: controller),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _PendingStep(
            done: controller.identityDone && controller.reviewSeen,
            pending: controller.identityDone && !controller.reviewSeen,
            title: 'Identity verification',
            subtitle: controller.identityDone && controller.reviewSeen
                ? 'Identity confirmed'
                : controller.identityDone
                ? 'Review pending...'
                : 'Submit your valid ID document',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      CardVerificationHubScreen(controller: controller),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _PendingStep(
            done: controller.addressDone && controller.reviewSeen,
            pending: controller.addressDone && !controller.reviewSeen,
            title: 'Residential address',
            subtitle: controller.addressDone && controller.reviewSeen
                ? 'Address confirmed'
                : controller.addressDone
                ? 'Review pending...'
                : 'Confirm your residential address',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      CardVerificationHubScreen(controller: controller),
                ),
              );
            },
          ),
          if (controller.allVerificationDone && !controller.reviewSeen) ...[
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: 'Check review status',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CardReviewPendingScreen(controller: controller),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingStep extends StatelessWidget {
  const _PendingStep({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.done,
    required this.pending,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool done;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (done)
                const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF16A34A),
                  size: 22,
                )
              else if (pending)
                const MiniHourglass()
              else
                const Icon(
                  Icons.circle_outlined,
                  color: AppColors.textMuted,
                  size: 22,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
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

// ─── Approved — create card ──────────────────────────────────────────────────

class _ApprovedView extends StatelessWidget {
  const _ApprovedView({required this.controller});

  final VirtualCardController controller;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'Cards',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 20),
                const VirtualCardVisual(last4: '78', angled: true),
                const SizedBox(height: 28),
                const Text(
                  'Card Request Pending',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Your details are under review. We'll notify you once\n"
                  "it's complete and you can create your virtual card.",
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 22),
                _PendingStep(
                  done: true,
                  pending: false,
                  title: 'Personal Information',
                  subtitle: 'Personal information confirmed',
                  onTap: () {},
                ),
                const SizedBox(height: 10),
                _PendingStep(
                  done: true,
                  pending: false,
                  title: 'Identity Verification',
                  subtitle: 'Identity confirmed',
                  onTap: () {},
                ),
                const SizedBox(height: 10),
                _PendingStep(
                  done: true,
                  pending: false,
                  title: 'Residential Address',
                  subtitle: 'Address confirmed',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
          child: AuthPrimaryButton(
            label: 'Create Virtual Card',
            onPressed: () {
              final hasPin =
                  context.read<UserSession>().user?.hasTransactionPin ?? false;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CardPinScreen(
                    controller: controller,
                    hasExistingPin: hasPin,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
