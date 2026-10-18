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
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => OtpPage(flow: flow)));
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
        title: 'Verify your email',
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
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    FocusScope.of(context).unfocus();
    context.read<OtpVerifyCubit>().submit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OtpVerifyCubit>();
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: BlocConsumer<OtpVerifyCubit, OtpVerifyState>(
            listenWhen: (previous, current) =>
                current.error != null && current.error != previous.error,
            listener: (context, state) {
              // The code was wrong or expired: let the user retype it.
              _controller.clear();
            },
            builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.subtitle),
                  const SizedBox(height: 4),
                  Text(
                    widget.destination,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    enabled: !state.isVerifying,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(OtpCode.length),
                    ],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, letterSpacing: 12),
                    decoration: InputDecoration(
                      hintText: '••••••',
                      counterText: '',
                      errorText: state.error,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      cubit.clearError();
                      if (value.length == OtpCode.length) _submit(context);
                    },
                    onSubmitted: (_) => _submit(context),
                  ),
                  if (state.resent)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('A new code has been sent'),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: state.isBusy ? null : () => _submit(context),
                      child: state.isVerifying
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Verify'),
                    ),
                  ),
                  if (cubit.canResend) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: state.isBusy || state.resendInSeconds > 0
                            ? null
                            : cubit.resend,
                        child: Text(
                          state.isResending
                              ? 'Sending…'
                              : state.resendInSeconds > 0
                              ? 'Resend code in ${state.resendInSeconds}s'
                              : 'Resend code',
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
