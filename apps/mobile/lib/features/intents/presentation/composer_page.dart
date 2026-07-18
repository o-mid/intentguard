import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('New intent')),
      body: SafeArea(
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
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    children: [
                      Text(
                        'What should happen?',
                        style: GoogleFonts.fraunces(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pick a chip or write your own. Plans are schema + policy checked before you approve.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.65),
                              height: 1.35,
                            ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _controller,
                        minLines: 3,
                        maxLines: 5,
                        onChanged: context.read<ComposerCubit>().setText,
                        decoration: const InputDecoration(
                          labelText: 'Intent',
                          hintText: 'e.g. swap 10 USDC',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Examples',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.55),
                            ),
                      ),
                      const SizedBox(height: 10),
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
                        const SizedBox(height: 16),
                        Text(
                          state.message!,
                          style: TextStyle(color: scheme.error, height: 1.35),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: FilledButton(
                    onPressed: loading
                        ? null
                        : () => context.read<ComposerCubit>().submit(),
                    child: Text(loading ? 'Planning…' : 'Create plan'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
