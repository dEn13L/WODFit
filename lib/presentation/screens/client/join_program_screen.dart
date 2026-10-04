import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../bloc/program/program_cubit.dart';
import '../../widgets/program_visual_banner.dart';
import '../../../core/theme/app_theme_extension.dart';

class JoinProgramScreen extends StatefulWidget {
  const JoinProgramScreen({super.key});

  @override
  State<JoinProgramScreen> createState() => _JoinProgramScreenState();
}

class _JoinProgramScreenState extends State<JoinProgramScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _onJoin() async {
    if (_isLoading || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    final success = await context.read<ProgramCubit>().joinProgram(
      _codeController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      if (success) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Вступление в программу'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocListener<ProgramCubit, ProgramState>(
        listener: (context, state) {
          if (state is ProgramError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: context.appTheme.destructive,
              ),
            );
          }
        },
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!keyboardOpen) ...[
                      const ProgramVisualBanner(
                        title: 'Тренируйтесь с тренером',
                        subtitle: 'Получите код приглашения у тренера',
                      ),
                      const SizedBox(height: 20),
                    ],
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Войти в программу',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Введите код, который вам прислал тренер',
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _codeController,
                                enabled: !_isLoading,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  if (!_isLoading) _onJoin();
                                },
                                textCapitalization:
                                    TextCapitalization.characters,
                                style: TextStyle(
                                  fontSize: 24,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Код приглашения',
                                  hintText: 'PROGXX',
                                  hintStyle: TextStyle(
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.4),
                                    letterSpacing: 4,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Введите код приглашения';
                                  }
                                  if (value.trim().length < 4) {
                                    return 'Код слишком короткий';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 32),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _onJoin,
                                child: _isLoading
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colorScheme.onPrimary,
                                        ),
                                      )
                                    : const Text(
                                        'Присоединиться к программе',
                                        textAlign: TextAlign.center,
                                      ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'После вступления тренировки появятся в вашем расписании',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
