import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/conversion.dart';
import '../bloc/converter_bloc.dart';
import '../bloc/converter_event.dart';
import '../bloc/converter_state.dart';

class ConverterPage extends StatelessWidget {
  const ConverterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ConverterBloc>(),
      child: const _ConverterView(),
    );
  }
}

class _ConverterView extends StatefulWidget {
  const _ConverterView();

  @override
  State<_ConverterView> createState() => _ConverterViewState();
}

class _ConverterViewState extends State<_ConverterView> {
  final _amountController = TextEditingController(text: '1');
  String _from = supportedCurrencyCodes.first;
  String _to = supportedCurrencyCodes[1];
  String? _inputError;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null) {
      setState(() => _inputError = 'Enter a valid amount');
      return;
    }

    setState(() => _inputError = null);
    context.read<ConverterBloc>().add(
      ConvertRequested(amount: amount, from: _from, to: _to),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Converter')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount',
              errorText: _inputError,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _from,
            decoration: const InputDecoration(
              labelText: 'From',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final code in supportedCurrencyCodes)
                DropdownMenuItem(value: code, child: Text(code)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _from = value);
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _to,
            decoration: const InputDecoration(
              labelText: 'To',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final code in supportedCurrencyCodes)
                DropdownMenuItem(value: code, child: Text(code)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _to = value);
            },
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _submit, child: const Text('Convert')),
          const SizedBox(height: 24),
          const _ConversionResult(),
        ],
      ),
    );
  }
}

class _ConversionResult extends StatelessWidget {
  const _ConversionResult();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConverterBloc, ConverterState>(
      builder: (context, state) {
        return switch (state) {
          ConverterInitial() => const Text('Enter an amount to convert.'),
          ConverterLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          ConverterSuccess(:final conversion) => Text(
            '${conversion.amount.toStringAsFixed(2)} ${conversion.from} = '
            '${conversion.result.toStringAsFixed(2)} ${conversion.to}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          ConverterFailure(:final message) => Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        };
      },
    );
  }
}
