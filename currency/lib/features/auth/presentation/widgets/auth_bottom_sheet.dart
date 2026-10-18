import 'package:flutter/material.dart';

/// Reusable "Log in or sign up" sheet.
///
/// Use it inline (e.g. docked at the bottom of a page):
/// ```dart
/// const AuthBottomSheet()
/// ```
/// or show it as a modal from any screen:
/// ```dart
/// AuthBottomSheet.show(context, onContinue: (phone) {});
/// ```
class AuthBottomSheet extends StatefulWidget {
  const AuthBottomSheet({
    super.key,
    this.onContinue,
    this.onGoogle,
    this.onApple,
    this.onEmail,
  });

  /// Called with the entered phone number (without country code).
  final ValueChanged<String>? onContinue;
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;
  final VoidCallback? onEmail;

  /// Shows the sheet as a modal bottom sheet.
  static Future<T?> show<T>(
    BuildContext context, {
    ValueChanged<String>? onContinue,
    VoidCallback? onGoogle,
    VoidCallback? onApple,
    VoidCallback? onEmail,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: AuthBottomSheet(
          onContinue: onContinue,
          onGoogle: onGoogle,
          onApple: onApple,
          onEmail: onEmail,
        ),
      ),
    );
  }

  static const _accent = Color(0xFFF0505F);
  static const _ink = Color(0xFF2B2F42);

  @override
  State<AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends State<AuthBottomSheet> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Log in or sign up',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AuthBottomSheet._ink,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildCountryPicker(),
                const SizedBox(width: 12),
                Expanded(child: _buildPhoneField()),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: () =>
                    widget.onContinue?.call(_phoneController.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: AuthBottomSheet._accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _SocialButton(
                    onTap: widget.onGoogle,
                    icon: const Text(
                      'G',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4285F4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _SocialButton(
                    onTap: widget.onApple,
                    icon: const Icon(Icons.apple, size: 32, color: Colors.black),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _SocialButton(
                    onTap: widget.onEmail,
                    icon: const Icon(
                      Icons.mail_rounded,
                      size: 28,
                      color: AuthBottomSheet._accent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              'By continuing, you agree to our',
              style: TextStyle(fontSize: 14, color: Color(0xFF5B6075)),
            ),
            const SizedBox(height: 6),
            const Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              children: [
                _LegalLink('Terms of Service'),
                _LegalLink('Privacy Policy'),
                _LegalLink('Content Policies'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryPicker() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: _fieldDecoration,
      child: const Row(
        children: [
          Text('🇮🇳', style: TextStyle(fontSize: 24)),
          SizedBox(width: 4),
          Icon(Icons.arrow_drop_down_rounded, color: Colors.grey, size: 28),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _fieldDecoration,
      child: Row(
        children: [
          const Text(
            '+91',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AuthBottomSheet._ink,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'Enter Mobile Number',
                hintStyle: TextStyle(color: Color(0xFF8A8FA3)),
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 17, color: AuthBottomSheet._ink),
            ),
          ),
        ],
      ),
    );
  }

  static final _fieldDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: const Color(0xFFE3E5EC)),
  );
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.icon, this.onTap});

  final Widget icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F4F8),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(height: 60, child: Center(child: icon)),
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF2B2F42),
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dotted,
      ),
    );
  }
}
