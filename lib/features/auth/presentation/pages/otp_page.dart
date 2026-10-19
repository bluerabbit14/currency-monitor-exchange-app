import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/otp_code.dart';
import '../bloc/otp_verify_cubit.dart';

/// Enter the 6-digit code. Shared by email sign-in and the Google link step;
/// a future phone flow reuses it unchanged.
class OtpPage extends StatelessWidget {
  const OtpPage({super.key, required this.flow});

  final OtpFlow flow;

  static Future<void> open(BuildContext context, OtpFlow flow) {
    return Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => OtpPage(flow: flow)));
  }

  String get _destination => switch (flow) {
    ContactOtpFlow(:final contact) => contact.value,
    GoogleLinkOtpFlow(:final maskedEmail) => maskedEmail,
  };

  String get _subtitle => switch (flow) {
    ContactOtpFlow() => 'We sent a 6-digit code to',
    GoogleLinkOtpFlow() =>
      'This email already has an account. Enter the 6-digit code we sent to '
          'confirm it is yours and link Google:',
  };

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OtpVerifyCubit>(param1: flow),
      child: _OtpView(
        title: 'Verify account with OTP',
        subtitle: _subtitle,
        destination: _destination,
      ),
    );
  }
}

class _OtpView extends StatefulWidget {
  const _OtpView({
    required this.title,
    required this.subtitle,
    required this.destination,
  });

  final String title;
  final String subtitle;
  final String destination;

  @override
  State<_OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<_OtpView> {
  static const _accent = Color(0xFFF0505F);
  static const _errorColor = Color(0xFFD93025);

  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Rebuild the boxes as the digits and focus change.
    _controller.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    FocusScope.of(context).unfocus();
    context.read<OtpVerifyCubit>().submit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OtpVerifyCubit>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: BlocConsumer<OtpVerifyCubit, OtpVerifyState>(
            listenWhen: (previous, current) =>
                current.error != null && current.error != previous.error,
            listener: (context, state) {
              // The code was wrong or expired: let the user retype it.
              _controller.clear();
              _focus.requestFocus();
            },
            builder: (context, state) {
              final hasError = state.error != null;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RoundBackButton(
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.isResending && cubit.canResend
                        ? 'Sending a 6-digit code to'
                        : widget.subtitle,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.destination,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 28),
                  _CodeBoxes(
                    controller: _controller,
                    focusNode: _focus,
                    enabled: !state.isVerifying,
                    hasError: hasError,
                    onChanged: (value) {
                      cubit.clearError();
                      if (value.length == OtpCode.length) _submit(context);
                    },
                    onSubmitted: () => _submit(context),
                  ),
                  if (hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        state.error!,
                        style: const TextStyle(
                          color: _errorColor,
                          fontSize: 15,
                        ),
                      ),
                    )
                  else if (state.resent)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('A new code has been sent'),
                    ),
                  if (cubit.canResend)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          alignment: Alignment.centerLeft,
                        ),
                        onPressed: state.isBusy || state.resendInSeconds > 0
                            ? null
                            : cubit.resend,
                        child: Text(
                          state.isResending
                              ? 'Sending…'
                              : state.resendInSeconds > 0
                              ? 'Resend code in ${state.resendInSeconds}s'
                              : 'Resend code',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: state.isBusy ? null : () => _submit(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: state.isVerifying
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Verify',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RoundBackButton extends StatelessWidget {
  const _RoundBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: CircleBorder(side: BorderSide(color: scheme.outlineVariant)),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox.square(
          dimension: 48,
          child: Icon(Icons.arrow_back, size: 22),
        ),
      ),
    );
  }
}

/// Six boxes showing the typed digits. One invisible [TextField] sits on top
/// and does the real work (keyboard, paste, one-time-code autofill), so the
/// boxes are purely visual.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hasError,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = controller.text;
    final activeIndex = focusNode.hasFocus
        ? text.length.clamp(0, OtpCode.length - 1)
        : -1;
    return Stack(
      children: [
        Row(
          children: [
            for (var i = 0; i < OtpCode.length; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              Expanded(
                child: _CodeBox(
                  digit: i < text.length ? text[i] : '',
                  borderColor: hasError
                      ? _OtpViewState._errorColor
                      : i == activeIndex
                      ? scheme.onSurface
                      : scheme.outlineVariant,
                  borderWidth: hasError || i == activeIndex ? 1.6 : 1,
                  fill: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
        Positioned.fill(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            enabled: enabled,
            showCursor: false,
            enableInteractiveSelection: false,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(OtpCode.length),
            ],
            // Invisible, but still receives taps, keys and autofill.
            style: const TextStyle(color: Colors.transparent, fontSize: 1),
            cursorColor: Colors.transparent,
            decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: onChanged,
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
      ],
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.digit,
    required this.borderColor,
    required this.borderWidth,
    required this.fill,
  });

  final String digit;
  final Color borderColor;
  final double borderWidth;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Text(
        digit,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      ),
    );
  }
}
