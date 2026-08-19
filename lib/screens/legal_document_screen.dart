import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';

class LegalSection {
  const LegalSection({required this.heading, required this.body});

  final String heading;
  final String body;
}

/// Shared chrome for long-form legal pages (Terms, Privacy).
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.lastUpdated,
    required this.sections,
  });

  final String title;
  final String subtitle;
  final String lastUpdated;
  final List<LegalSection> sections;

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
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 28 + bottom),
                  children: [
                    AuthTitleBlock(title: title, subtitle: subtitle),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: Color(0xFF4F6BED),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Last updated $lastUpdated',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4F6BED),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < sections.length; i++) ...[
                            if (i > 0) const SizedBox(height: 8),
                            _SectionBlock(
                              index: i + 1,
                              section: sections[i],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.index, required this.section});

  final int index;
  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$index. ${section.heading}',
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            section.body,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.55,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Terms of Service for Crownex (fintech / crypto / bills app).
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  static const _sections = <LegalSection>[
    LegalSection(
      heading: 'Agreement to these Terms',
      body:
          'By creating a Crownex account or using the Crownex mobile application (“App”), you agree to these Terms of Service (“Terms”). If you do not agree, do not use the App. Crownex provides digital wallet, cryptocurrency exchange, bill payment, gift card, and virtual card services. These Terms form a binding agreement between you and Crownex.',
    ),
    LegalSection(
      heading: 'Eligibility',
      body:
          'You must be at least 18 years old and capable of entering a binding contract under the laws of your country of residence. You may be required to complete identity verification (KYC) before accessing certain features such as higher withdrawal limits, virtual cards, or crypto transfers. You represent that information you provide is accurate and complete.',
    ),
    LegalSection(
      heading: 'Your account',
      body:
          'You are responsible for safeguarding your login credentials, one-time passwords (OTPs), and 4-digit transaction PIN. You must not share them with anyone. Activities performed through your account are considered authorized by you unless you promptly notify us of unauthorized access. Crownex may suspend or restrict accounts that appear compromised, abusive, or used for illegal activity.',
    ),
    LegalSection(
      heading: 'Services we provide',
      body:
          'Crownex may offer: (a) Naira wallet deposits and withdrawals; (b) cryptocurrency deposits, swaps, and transfers on supported networks; (c) airtime, data, electricity, and cable TV payments; (d) gift card purchases; and (e) virtual card creation and spending. Features may vary by region, verification status, and product availability. We may add, modify, or discontinue features with reasonable notice where required by law.',
    ),
    LegalSection(
      heading: 'Crypto services',
      body:
          'Cryptocurrency prices are volatile. Swaps execute at the rate displayed at confirmation and may differ from earlier quotes. You are solely responsible for selecting the correct asset and network when depositing or withdrawing crypto. Funds sent to an incorrect address or on an unsupported network may be permanently lost and are generally not recoverable by Crownex. Blockchain confirmations and network congestion can delay deposits and transfers.',
    ),
    LegalSection(
      heading: 'Bill payments, gift cards & virtual cards',
      body:
          'When you buy airtime, data, electricity tokens, cable subscriptions, or gift cards, you must enter correct beneficiary details. Successful payments are typically final. Virtual cards are subject to issuer rules, merchant acceptance, and available balance. Misuse of cards, gift codes, or bill services may result in suspension and recovery of losses where permitted by law.',
    ),
    LegalSection(
      heading: 'Fees',
      body:
          'Service fees, network (gas) fees, and payment processor charges may apply. Fees are disclosed in the App before you confirm a transaction. Crownex may update fee schedules; continued use after notice constitutes acceptance of updated fees for future transactions.',
    ),
    LegalSection(
      heading: 'Prohibited use',
      body:
          'You agree not to use Crownex for fraud, money laundering, terrorist financing, sanctions evasion, unauthorized carding, phishing, or any illegal activity. You must not reverse-engineer the App, disrupt our systems, create multiple accounts to evade limits, or use automated means without permission. We may freeze funds and report activity to authorities when required.',
    ),
    LegalSection(
      heading: 'Transaction finality & disputes',
      body:
          'Once a crypto transfer is broadcast, a bill is paid, or a gift card is delivered, the transaction may be irreversible. Review all details carefully before confirming with your PIN. If you believe a transaction was unauthorized or failed incorrectly, contact support promptly with the transaction reference. Chargebacks and bank disputes are handled under applicable payment partner rules.',
    ),
    LegalSection(
      heading: 'Availability & third parties',
      body:
          'The App depends on banking partners, crypto liquidity providers, bill payment aggregators, gift card suppliers, and card issuers. Outages, rate limits, or partner failures may temporarily affect services. Crownex does not guarantee uninterrupted availability and is not liable for delays caused solely by third-party networks beyond our reasonable control.',
    ),
    LegalSection(
      heading: 'Limitation of liability',
      body:
          'To the maximum extent permitted by law, Crownex and its affiliates are not liable for indirect, incidental, special, consequential, or punitive damages, or for loss of profits, data, or goodwill arising from your use of the App. Our total liability for any claim relating to the services is limited to the fees you paid to Crownex in the three months preceding the claim, except where liability cannot be limited by law (including fraud or death/personal injury caused by negligence).',
    ),
    LegalSection(
      heading: 'Termination',
      body:
          'You may stop using Crownex at any time. We may suspend or terminate access if you breach these Terms, if required by law or partners, or to protect users and the platform. Upon closure, you should withdraw eligible balances subject to compliance checks, outstanding fees, and applicable holds.',
    ),
    LegalSection(
      heading: 'Changes to these Terms',
      body:
          'We may update these Terms to reflect product, legal, or operational changes. Material updates will be indicated by a new “Last updated” date in the App. Continued use after the effective date constitutes acceptance of the revised Terms.',
    ),
    LegalSection(
      heading: 'Contact',
      body:
          'Questions about these Terms can be sent to support@crownexapp.com or submitted via Settings → Contact Support in the App. For privacy-related requests, see our Privacy Policy.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Terms of Service',
      subtitle: 'The rules for using Crownex wallet, crypto, and payment services',
      lastUpdated: 'July 25, 2026',
      sections: _sections,
    );
  }
}

/// Privacy Policy for Crownex.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = <LegalSection>[
    LegalSection(
      heading: 'Introduction',
      body:
          'This Privacy Policy explains how Crownex (“we”, “us”) collects, uses, stores, and shares personal information when you use the Crownex mobile application and related services. We are committed to protecting your privacy while delivering wallet, crypto, bill payment, gift card, and virtual card features.',
    ),
    LegalSection(
      heading: 'Information we collect',
      body:
          'We may collect: (a) account data — full name, email address, phone number, and profile photo; (b) authentication data — passwords (stored hashed), OTPs, and transaction PIN verification signals; (c) financial activity — wallet balances, deposits, withdrawals, crypto deposits/swaps/transfers, bill payments, gift card purchases, and virtual card transactions; (d) device and app data — device type, OS, app version, and approximate diagnostics; and (e) support communications you send us. We do not ask for your banking password or seed phrases.',
    ),
    LegalSection(
      heading: 'How we use your information',
      body:
          'We use personal data to: create and secure your account; process payments and crypto operations; display balances and transaction history; complete bill, gift card, and virtual card requests; prevent fraud and abuse; meet legal and regulatory obligations (including KYC/AML where applicable); improve the App; and respond to support requests.',
    ),
    LegalSection(
      heading: 'Legal bases (where applicable)',
      body:
          'Depending on your location, we process data based on: performance of a contract (providing the services you request); legitimate interests (security, product improvement, fraud prevention); legal obligations (record-keeping, sanctions screening); and consent where required (for example, certain optional marketing or device permissions such as camera for profile photos).',
    ),
    LegalSection(
      heading: 'Sharing of information',
      body:
          'We share data only as needed with: payment processors and banks for Naira deposits/withdrawals; crypto infrastructure and liquidity partners for digital asset services; bill payment and gift card providers to fulfill orders; virtual card issuers/processors; cloud hosting and analytics tools under contract; and authorities when required by law or to protect rights and safety. We do not sell your personal information.',
    ),
    LegalSection(
      heading: 'Security',
      body:
          'We use encryption in transit (HTTPS), secure token storage on device for session tokens, server-side authentication, and a transaction PIN for sensitive actions. No method of transmission or storage is 100% secure. You help protect your account by using a strong password, not sharing OTPs or your PIN, and keeping your device updated.',
    ),
    LegalSection(
      heading: 'Data retention',
      body:
          'We retain account and transaction records for as long as your account is active and for a period afterward as required for legal, tax, dispute, and fraud-prevention purposes. Support tickets and logs may be retained for a reasonable period to improve service quality. You may request account closure; some records may still be kept where the law requires.',
    ),
    LegalSection(
      heading: 'Your rights',
      body:
          'Subject to applicable law, you may request access to, correction of, or deletion of certain personal data; object to or restrict some processing; and withdraw consent where processing is consent-based. You can update name, phone, and photo in Settings → Personal Information, and change your password or transaction PIN in-app. Contact support@crownexapp.com for other privacy requests. We may need to verify your identity before fulfilling requests.',
    ),
    LegalSection(
      heading: 'Children',
      body:
          'Crownex is not directed at children under 18. We do not knowingly collect personal information from minors. If you believe a minor has created an account, contact us so we can take appropriate action.',
    ),
    LegalSection(
      heading: 'International transfers',
      body:
          'Your information may be processed in countries other than your own where our servers or partners operate. Where required, we use appropriate safeguards for cross-border transfers consistent with applicable data protection laws.',
    ),
    LegalSection(
      heading: 'Changes to this Policy',
      body:
          'We may update this Privacy Policy from time to time. The “Last updated” date in the App will reflect material changes. Continued use of Crownex after an update means you acknowledge the revised Policy.',
    ),
    LegalSection(
      heading: 'Contact us',
      body:
          'For privacy questions or requests, email support@crownexapp.com or use Settings → Contact Support. We aim to respond within a reasonable timeframe consistent with applicable law.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      title: 'Privacy Policy',
      subtitle: 'How Crownex collects, uses, and protects your information',
      lastUpdated: 'July 25, 2026',
      sections: _sections,
    );
  }
}
