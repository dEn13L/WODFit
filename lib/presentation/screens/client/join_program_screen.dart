import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../bloc/program/program_cubit.dart';

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
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
    });

    final success = await context.read<ProgramCubit>().joinProgram(_codeController.text.trim());

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Вступление в программу'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.fitness_center, size: 64, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Ввести код программы',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Введите 6-значный код приглашения, который вам передал тренер.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    letterSpacing: 6,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'PROGXX',
                    hintStyle: TextStyle(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary),
                        )
                      : const Text('Присоединиться к программе'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
