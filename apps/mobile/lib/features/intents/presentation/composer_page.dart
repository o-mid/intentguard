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

  /// Natural-language prompts for an LLM-planner demo feel.
  static const _llmPrompts = [
    _ExampleChip(
      text:
          'hey, can you swap about 10 USDC into ETH for me when gas looks fine?',
      hint: 'LLM-style · should pass',
      pass: true,
    ),
    _ExampleChip(
      text:
          'please transfer 5 USDC to my allowlisted wallet, nothing fancy',
      hint: 'LLM-style · should pass',
      pass: true,
    ),
    _ExampleChip(
      text: 'bridge my funds somewhere else real quick, I trust you',
      hint: 'LLM-style · schema reject',
      pass: false,
    ),
    _ExampleChip(
      text: 'go ahead and swap 150 USDC, I need a bigger position today',
      hint: 'LLM-style · policy reject',
      pass: false,
    ),
  ];

  /// Short fixture chips (second line).
  static const _chips = [
    _ExampleChip(text: 'swap 10 USDC', hint: 'Pass', pass: true),
    _ExampleChip(text: 'transfer 5 USDC', hint: 'Pass', pass: true),
    _ExampleChip(text: 'bridge funds somewhere', hint: 'Reject', pass: false),
    _ExampleChip(text: 'swap 150 USDC', hint: 'Reject', pass: false),
  ];

  static const _starterPrompt =
      'hey, can you swap about 10 USDC into ETH for me when gas looks fine?';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _starterPrompt);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<ComposerCubit>().setText(_starterPrompt);
    });
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
          listenWhen: (prev, next) =>
              prev.text != next.text ||
              (prev.status != ComposerStatus.ready &&
                  next.status == ComposerStatus.ready),
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
                        'Type a natural ask like you would to an LLM. The planner turns it into a schema plan, then policy checks it before any approve.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.65),
                              height: 1.35,
                            ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _controller,
                        minLines: 3,
                        maxLines: 6,
                        onChanged: context.read<ComposerCubit>().setText,
                        decoration: const InputDecoration(
                          labelText: 'Intent',
                          hintText:
                              'e.g. hey, can you swap 10 USDC into ETH for me?',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'LLM-style prompts',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Random natural language — tap to fill the field',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.55),
                            ),
                      ),
                      const SizedBox(height: 12),
                      ..._llmPrompts.map(
                        (example) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ExampleChipTile(
                            example: example,
                            enabled: !loading,
                            onTap: () => context
                                .read<ComposerCubit>()
                                .useChip(example.text),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Short chips',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Same fixtures, compact — green pass · red reject',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.55),
                            ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _chips
                            .map(
                              (chip) => _ShortChip(
                                example: chip,
                                enabled: !loading,
                                onTap: () => context
                                    .read<ComposerCubit>()
                                    .useChip(chip.text),
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

class _ExampleChip {
  const _ExampleChip({
    required this.text,
    required this.hint,
    required this.pass,
  });

  final String text;
  final String hint;
  final bool pass;
}

class _ExampleChipTile extends StatelessWidget {
  const _ExampleChipTile({
    required this.example,
    required this.enabled,
    required this.onTap,
  });

  final _ExampleChip example;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border =
        example.pass ? const Color(0xFF74C69D) : const Color(0xFFFECACA);
    final bg =
        example.pass ? const Color(0xFFEFFAF3) : const Color(0xFFFFF5F5);
    final badge =
        example.pass ? const Color(0xFF1B4332) : const Color(0xFF912018);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 1.4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      example.text,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0E1A16),
                            height: 1.3,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      example.hint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: badge,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                example.pass
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
                color: badge,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortChip extends StatelessWidget {
  const _ShortChip({
    required this.example,
    required this.enabled,
    required this.onTap,
  });

  final _ExampleChip example;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border =
        example.pass ? const Color(0xFF74C69D) : const Color(0xFFFECACA);
    final bg =
        example.pass ? const Color(0xFFEFFAF3) : const Color(0xFFFFF5F5);
    final fg =
        example.pass ? const Color(0xFF1B4332) : const Color(0xFF912018);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: 1.3),
          ),
          child: Text(
            example.text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}
