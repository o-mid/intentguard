import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'cubit/composer_cubit.dart';
import 'cubit/composer_state.dart';

class ComposerPage extends StatefulWidget {
  const ComposerPage({super.key});

  @override
  State<ComposerPage> createState() => _ComposerPageState();
}

class _ComposerPageState extends State<ComposerPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New intent')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: BlocConsumer<ComposerCubit, ComposerState>(
            listener: (context, state) {
              if (state.text != _controller.text) {
                _controller.text = state.text;
                _controller.selection =
                    TextSelection.collapsed(offset: state.text.length);
              }
              if (state.status == ComposerStatus.ready && state.result != null) {
                context.push('/plans/${state.result!.plan.id}');
              }
            },
            builder: (context, state) {
              final loading = state.status == ComposerStatus.loading;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controller,
                    minLines: 3,
                    maxLines: 5,
                    onChanged: context.read<ComposerCubit>().setText,
                    decoration: const InputDecoration(
                      labelText: 'Intent',
                      hintText: 'swap 10 USDC',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ComposerCubit.exampleChips
                        .map(
                          (chip) => ActionChip(
                            label: Text(chip),
                            onPressed: loading
                                ? null
                                : () => context.read<ComposerCubit>().useChip(chip),
                          ),
                        )
                        .toList(),
                  ),
                  if (state.message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.message!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const Spacer(),
                  FilledButton(
                    onPressed: loading
                        ? null
                        : () => context.read<ComposerCubit>().submit(),
                    child: Text(loading ? 'Planning…' : 'Create plan'),
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
