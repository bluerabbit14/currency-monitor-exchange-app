import 'package:flutter/material.dart';

import 'google_sign_in_button.dart';

/// Reusable "Log in or sign up" sheet.
///
/// Use it inline (e.g. docked at the bottom of a page):
/// ```dart
/// const AuthBottomSheet()
/// ```
/// or show it as a modal from any screen:
/// ```dart
/// AuthBottomSheet.show(context, onContinue: (email) {});
/// ```
class AuthBottomSheet extends StatefulWidget {
  const AuthBottomSheet({
    super.key,
    this.onContinue,
    this.onGoogle,
    this.onApple,
    this.isContinueLoading = false,
    this.isGoogleLoading = false,
    this.emailError,
  });

  /// Shows a spinner on the Continue button and disables it while true.
  final bool isContinueLoading;

  /// Shows a spinner on the Google button and disables it while true.
  final bool isGoogleLoading;

  /// Inline validation message shown under the email field.
  final String? emailError;

  /// Called with the entered email address (untrimmed; the caller validates).
  final ValueChanged<String>? onContinue;
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;

  /// Shows the sheet as a modal bottom sheet.
  static Future<T?> show<T>(
    BuildContext context, {
    ValueChanged<String>? onContinue,
    VoidCallback? onGoogle,
    VoidCallback? onApple,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AuthBottomSheet(
          onContinue: onContinue,
          onGoogle: onGoogle,
          onApple: onApple,
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
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(10, 0, 10, 20),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(32),
          bottom: Radius.circular(32),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Log in or sign up',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AuthBottomSheet._ink,
              ),
            ),
            const SizedBox(height: 20),
            // Mobile OTP (future release): add the country picker + phone
            // field here and pass the E.164 number as a PhoneContact.
            _buildEmailField(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: _appleButtonHeight,
              child: FilledButton(
                onPressed: widget.isContinueLoading || widget.isGoogleLoading
                    ? null
                    : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AuthBottomSheet._accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: widget.isContinueLoading
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            const _OrDivider(),
            const SizedBox(height: 20),
            GoogleSignInButton(
              borderRadius: 14,
              isLoading: widget.isGoogleLoading,
              onPressed: widget.isContinueLoading ? null : widget.onGoogle,
            ),
            const SizedBox(height: 12),
            // Black Apple button with a white logo, sized to match the other
            _appleButton(context),
            const SizedBox(height: 24),
            const Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                Text(
                  'By continuing, you agree to our',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5B6075)),
                ),
                _LegalLink('Terms of Service'),
                Text(
                  'and',
                  style: TextStyle(fontSize: 12, color: Color(0xFF5B6075)),
                ),
                _LegalLink('Privacy Policy'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const _appleButtonHeight = 54.0;

  /// Black button with a white Apple logo, matching the Google button's size
  /// and label.
  Widget _appleButton(BuildContext context) {
    return SizedBox(
      height: _appleButtonHeight,
      width: double.infinity,
      child: Material(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onApple ?? () {},
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.apple, color: Colors.white, size: 26),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Continue with Apple',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: GoogleSignInButton.labelFontSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    widget.onContinue?.call(_emailController.text);
  }

  Widget _buildEmailField() {
    final hasError = widget.emailError != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: _appleButtonHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: _fieldDecoration.copyWith(
            border: Border.all(
              color: hasError
                  ? const Color(0xFFD93025)
                  : const Color(0xFFE3E5EC),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.mail_outline_rounded, color: Color(0xFF8A8FA3)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.email],
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    hintText: 'Enter your email',
                    hintStyle: TextStyle(color: Color(0xFF8A8FA3)),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(
                    fontSize: 17,
                    color: AuthBottomSheet._ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              widget.emailError!,
              style: const TextStyle(fontSize: 13, color: Color(0xFFD93025)),
            ),
          ),
      ],
    );
  }

  static final _fieldDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: const Color(0xFFE3E5EC)),
  );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    const line = Expanded(child: Divider(height: 1, color: Color(0xFFE3E5EC)));
    return const Row(
      children: [
        line,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or',
            style: TextStyle(fontSize: 14, color: Color(0xFF8A8FA3)),
          ),
        ),
        line,
      ],
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
        fontSize: 12,
        color: Color(0xFF2B2F42),
        fontWeight: FontWeight(600),
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.solid,
      ),
    );
  }
}
