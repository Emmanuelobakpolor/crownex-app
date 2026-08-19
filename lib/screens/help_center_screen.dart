import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import 'contact_support_screen.dart';

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

class _FaqCategory {
  const _FaqCategory({
    required this.title,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final List<_FaqItem> items;
}

/// In-app Help Center with searchable FAQs for Crownex products.
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  static const _categories = <_FaqCategory>[
    _FaqCategory(
      title: 'Getting started',
      icon: Icons.rocket_launch_outlined,
      iconBg: Color(0xFFE0E7FF),
      iconColor: Color(0xFF4F6BED),
      items: [
        _FaqItem(
          question: 'What is Crownex?',
          answer:
              'Crownex is your all-in-one finance app for crypto exchange, Naira wallet funding, bill payments (airtime, data, electricity, cable TV), gift cards, and virtual cards — all from one secure place.',
        ),
        _FaqItem(
          question: 'How do I create an account?',
          answer:
              'Tap Sign Up, enter your email and phone number, verify the OTP sent to your email, complete your profile, then set a 4-digit transaction PIN. You can sign in anytime with your email and password.',
        ),
        _FaqItem(
          question: 'What is a transaction PIN?',
          answer:
              'Your transaction PIN is a 4-digit code used to authorize sensitive actions like withdrawals and transfers. Keep it private. You can change it anytime from Settings → Security & Transaction PIN.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Wallet & deposits',
      icon: Icons.account_balance_wallet_outlined,
      iconBg: Color(0xFFD4FBF6),
      iconColor: Color(0xFF14B8A6),
      items: [
        _FaqItem(
          question: 'How do I fund my Naira wallet?',
          answer:
              'From Home, tap Deposit (or Top up) and follow the prompts to add NGN to your balance. Funds appear once payment is confirmed.',
        ),
        _FaqItem(
          question: 'How do I withdraw Naira?',
          answer:
              'Open Withdraw from Home, enter the amount and bank details, then confirm with your transaction PIN. Withdrawals are processed to your linked Nigerian bank account.',
        ),
        _FaqItem(
          question: 'Why is my balance not updating?',
          answer:
              'Pull to refresh on Home or wait a moment after a deposit. Bank and payment network delays can take a few minutes. If the amount is still missing after 30 minutes, contact support with your transaction reference.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Crypto',
      icon: Icons.currency_bitcoin_rounded,
      iconBg: Color(0xFFFFF0D6),
      iconColor: Color(0xFFE0A100),
      items: [
        _FaqItem(
          question: 'Which cryptocurrencies does Crownex support?',
          answer:
              'Crownex lets you deposit, swap, and transfer major cryptocurrencies available in the Crypto section of the app. Open Crypto to see the live list of supported assets and networks.',
        ),
        _FaqItem(
          question: 'How do I deposit crypto?',
          answer:
              'Go to Crypto → Deposit, choose the asset and network, then send crypto only to the address shown. Always double-check the network — sending on the wrong network can result in permanent loss of funds.',
        ),
        _FaqItem(
          question: 'How do crypto swaps work?',
          answer:
              'Open Crypto → Swap, select the pair, review the rate and any fees, then confirm. Swaps execute at the rate shown at confirmation time and may vary with market conditions.',
        ),
        _FaqItem(
          question: 'Are crypto deposits and withdrawals free?',
          answer:
              'Network (gas) fees and platform service fees may apply. Exact fees are shown before you confirm each deposit, swap, or transfer.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Bills & airtime',
      icon: Icons.phone_android_rounded,
      iconBg: Color(0xFFD6F0FF),
      iconColor: Color(0xFF2B9EDB),
      items: [
        _FaqItem(
          question: 'What bills can I pay?',
          answer:
              'You can buy airtime and data, pay electricity bills, and renew cable TV subscriptions directly from Home. Select the service, enter details, and pay from your Crownex wallet balance.',
        ),
        _FaqItem(
          question: 'My airtime or data did not drop — what do I do?',
          answer:
              'Confirm the phone number and network were correct. Most top-ups complete within a few minutes. Check Transaction History for status. If it failed, funds are usually reversed automatically; if not, contact support with the transaction ID.',
        ),
        _FaqItem(
          question: 'How do electricity token purchases work?',
          answer:
              'Choose your electricity provider, enter your meter number and amount, then pay. Your token is shown on the success screen and in Transaction History so you can enter it on your meter.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Gift cards & virtual cards',
      icon: Icons.card_giftcard_rounded,
      iconBg: Color(0xFFCFF5E1),
      iconColor: Color(0xFF1FAE63),
      items: [
        _FaqItem(
          question: 'How do I buy a gift card?',
          answer:
              'Open Gift Cards from Home, pick a brand and amount, complete payment from your wallet, and view the card code in Gift Card History. Keep codes private — treat them like cash.',
        ),
        _FaqItem(
          question: 'What is a Crownex virtual card?',
          answer:
              'A virtual card is a digital payment card you can create in the Cards tab for online payments. Complete any required identity verification, fund the card, then use the card details where cards are accepted.',
        ),
        _FaqItem(
          question: 'Why was my virtual card declined?',
          answer:
              'Common causes include insufficient card balance, merchant restrictions, expired card, or incomplete verification. Check your card balance and status in the Cards tab, then try again or contact support.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Security & account',
      icon: Icons.shield_outlined,
      iconBg: Color(0xFFFFE0E0),
      iconColor: Color(0xFFE53935),
      items: [
        _FaqItem(
          question: 'How do I reset my password?',
          answer:
              'On the sign-in screen, tap Forgot password, enter your email, verify the reset code, and set a new password. Never share OTPs or passwords with anyone claiming to be Crownex support.',
        ),
        _FaqItem(
          question: 'How do I change my transaction PIN?',
          answer:
              'Go to Settings → Security & Transaction PIN. Enter your current PIN, then set and confirm a new 4-digit PIN.',
        ),
        _FaqItem(
          question: 'Is my money safe on Crownex?',
          answer:
              'We use industry-standard encryption, secure authentication (JWT sessions), and a transaction PIN for sensitive actions. Never share your password, OTP, or PIN. Crownex staff will never ask for these.',
        ),
      ],
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_FaqCategory> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _categories;

    return _categories
        .map((cat) {
          final items = cat.items
              .where(
                (item) =>
                    item.question.toLowerCase().contains(q) ||
                    item.answer.toLowerCase().contains(q) ||
                    cat.title.toLowerCase().contains(q),
              )
              .toList();
          if (items.isEmpty) return null;
          return _FaqCategory(
            title: cat.title,
            icon: cat.icon,
            iconBg: cat.iconBg,
            iconColor: cat.iconColor,
            items: items,
          );
        })
        .whereType<_FaqCategory>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final filtered = _filtered;

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
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + bottom),
                  children: [
                    const AuthTitleBlock(
                      title: 'Help Center',
                      subtitle: 'Find answers about wallet, crypto, bills, and more',
                    ),
                    const SizedBox(height: 20),
                    _SearchField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: 20),
                    if (filtered.isEmpty)
                      const _EmptySearch()
                    else
                      ...filtered.map(
                        (cat) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _CategoryCard(category: cat),
                        ),
                      ),
                    const SizedBox(height: 8),
                    _StillNeedHelpCard(
                      onContact: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ContactSupportScreen(),
                          ),
                        );
                      },
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'Search help articles…',
        hintStyle: const TextStyle(
          fontSize: 15,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textMuted,
          size: 22,
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final _FaqCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: category.iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(category.icon, size: 18, color: category.iconColor),
                ),
                const SizedBox(width: 12),
                Text(
                  category.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          ...category.items.asMap().entries.map((entry) {
            final isLast = entry.key == category.items.length - 1;
            return _FaqTile(item: entry.value, isLast: isLast);
          }),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.item, required this.isLast});

  final _FaqItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.textMuted,
        shape: isLast
            ? const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              )
            : null,
        title: Text(
          item.question,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            height: 1.3,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item.answer,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'No matching articles',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Try a different keyword, or contact support for personal help.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StillNeedHelpCard extends StatelessWidget {
  const _StillNeedHelpCard({required this.onContact});

  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryGradientEnd],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Still need help?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Our support team is ready to assist with account, payments, and crypto issues.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onContact,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Contact Support',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
