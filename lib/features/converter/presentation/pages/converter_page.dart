import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/format/number_format.dart';
import '../bloc/converter_cubit.dart';
import '../widgets/calculator_keypad.dart';
import '../widgets/converter_row.dart';
import 'add_currency_page.dart';

const _background = Color(0xFFF1F1F6);
const _muted = Color(0xFF8A8A93);
const _red = Color(0xFFFF3B30);

class ConverterPage extends StatelessWidget {
  const ConverterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ConverterCubit>()..load(),
      child: const _ConverterView(),
    );
  }
}

class _ConverterView extends StatelessWidget {
  const _ConverterView();

  Future<void> _add(BuildContext context) async {
    final cubit = context.read<ConverterCubit>();
    final selected = await showAddCurrencyPage(context, cubit.state.assets);
    if (selected != null) await cubit.setAssets(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<ConverterCubit, ConverterState>(
          // A failed rate fetch keeps the rows and says why.
          listenWhen: (previous, current) =>
              current.error != null && current.error != previous.error,
          listener: (context, state) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.error!)));
          },
          builder: (context, state) {
            final cubit = context.read<ConverterCubit>();
            return LayoutBuilder(
              builder: (context, constraints) {
                // The keypad keeps its size on a normal screen and shrinks on
                // a short one (landscape, big text) to at most 45% of the
                // height; the header is capped the same way and scrolls.
                final keyHeight = ((constraints.maxHeight * 0.45 - 40) / 5)
                    .clamp(18.0, 56.0);
                return Column(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.3,
                      ),
                      child: SingleChildScrollView(
                        child: _Header(
                          updatedAt: state.updatedAt,
                          onAdd: () => _add(context),
                          onClear: state.assets.isEmpty ? null : cubit.clear,
                        ),
                      ),
                    ),
                    // Only the list scrolls; the keypad below stays put.
                    Expanded(child: _list(context, state, cubit)),
                    CalculatorKeypad(
                      onKey: cubit.keyPressed,
                      keyHeight: keyHeight,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _list(BuildContext context, ConverterState state, ConverterCubit c) {
    if (state.status == ConverterStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.assets.isEmpty) {
      // Scrolls so it never overflows on a short screen.
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No currencies yet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add the currencies you want to compare.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _add(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Currency'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        itemCount: state.assets.length,
        itemBuilder: (context, i) {
          final asset = state.assets[i];
          final active = asset.symbol == state.activeSymbol;
          return ConverterRow(
            asset: asset,
            value: _valueText(state, asset.symbol),
            active: active,
            showDivider: i < state.assets.length - 1,
            onTap: () => c.selectActive(asset.symbol),
            onDelete: () => c.remove(asset.symbol),
          );
        },
      ),
    );
  }

  /// The active row shows what is being typed; the others the converted
  /// amount, "-" when their rate is not known, and nothing while it loads.
  static String _valueText(ConverterState state, String symbol) {
    if (symbol == state.activeSymbol) {
      return state.expression.isEmpty ? '0' : state.expression;
    }
    if (state.failed.contains(symbol)) return '-';
    final value = state.convertedValue(symbol);
    return value == null ? '...' : formatAmount(value);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.updatedAt,
    required this.onAdd,
    required this.onClear,
  });

  final DateTime? updatedAt;
  final VoidCallback onAdd;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Converter',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                Text(
                  updatedAt == null ? ' ' : updatedLabel(updatedAt!),
                  style: const TextStyle(fontSize: 14, color: _muted),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            position: PopupMenuPosition.under,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onSelected: (value) {
              if (value == 'add') onAdd();
              if (value == 'clear') onClear?.call();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'add',
                child: ListTile(
                  leading: Icon(Icons.add),
                  title: Text('Add Currency'),
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                enabled: onClear != null,
                child: const ListTile(
                  leading: Icon(Icons.delete_outline, color: _red),
                  title: Text('Clear', style: TextStyle(color: _red)),
                ),
              ),
            ],
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(top: 6),
              decoration: const BoxDecoration(
                color: Color(0xFFD9D9DE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.more_horiz, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Updated just now", "Updated 5 min ago", "Updated today at 17:34" or
/// "Updated 3 Oct at 17:34".
String updatedLabel(DateTime at, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final local = at.toLocal();
  final age = current.difference(local);
  if (age.inMinutes < 1) return 'Updated just now';
  if (age.inMinutes < 60) return 'Updated ${age.inMinutes} min ago';
  final time = DateFormat('HH:mm').format(local);
  final sameDay =
      local.year == current.year &&
      local.month == current.month &&
      local.day == current.day;
  return sameDay
      ? 'Updated today at $time'
      : 'Updated ${DateFormat('d MMM').format(local)} at $time';
}
