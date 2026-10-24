import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../bloc/feedback_cubit.dart';

/// Feedback bottom sheet: a star rating and a comment, both optional but at
/// least one is needed to send. Returns true when the feedback was sent.
Future<bool> showFeedbackSheet(BuildContext context) async {
  final cubit = sl<FeedbackCubit>();
  try {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const _FeedbackSheet()),
    );
    return sent ?? false;
  } finally {
    await cubit.close();
  }
}

const _blue = Color(0xFF0A84FF);
const _muted = Color(0xFF6E6E76);
const _card = Color(0xFFF1F1F6);
const _star = Color(0xFFFFB800);
const _maxLength = 2000;

class _FeedbackSheet extends StatelessWidget {
  const _FeedbackSheet();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FeedbackCubit, FeedbackState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == FeedbackStatus.sent,
      listener: (context, state) => Navigator.of(context).pop(true),
      builder: (context, state) {
        final cubit = context.read<FeedbackCubit>();
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D1D6),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Send feedback',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Rate the app, leave a comment, or both.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: _muted),
                  ),
                  const SizedBox(height: 20),
                  _Stars(
                    rating: state.rating,
                    enabled: !state.isSending,
                    onChanged: cubit.setRating,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    enabled: !state.isSending,
                    onChanged: cubit.setMessage,
                    minLines: 4,
                    maxLines: 6,
                    maxLength: _maxLength,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Tell us what you think (optional)',
                      filled: true,
                      fillColor: _card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFD62F2F),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: state.canSubmit && !state.isSending
                        ? cubit.submit
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: state.isSending
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
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

class _Stars extends StatelessWidget {
  const _Stars({
    required this.rating,
    required this.enabled,
    required this.onChanged,
  });

  final int? rating;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: i == 1 ? '1 star' : '$i stars',
            onPressed: enabled ? () => onChanged(i) : null,
            iconSize: 40,
            icon: Icon(
              i <= (rating ?? 0)
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: i <= (rating ?? 0) ? _star : const Color(0xFFC7C7CC),
            ),
          ),
      ],
    );
  }
}
