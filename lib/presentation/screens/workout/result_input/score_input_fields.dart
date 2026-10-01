import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'result_input_parsers.dart';

InputDecoration _decoration(
  BuildContext context, {
  required String label,
  String? hint,
  String? suffix,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixText: suffix,
    filled: true,
    fillColor: colorScheme.surfaceContainerHighest,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

class TimeScoreField extends StatelessWidget {
  final TextEditingController minutesController;
  final TextEditingController secondsController;

  const TimeScoreField({
    super.key,
    required this.minutesController,
    required this.secondsController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FormField<ParsedWorkoutTime>(
      validator: (_) => parseWorkoutTime(
        minutesController.text,
        secondsController.text,
      ) == null
          ? 'Введите время, секунды — от 00 до 59'
          : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Время', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: field.hasError
                  ? Border.all(color: theme.colorScheme.error)
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimePartField(
                  controller: minutesController,
                  semanticsLabel: 'Минуты',
                  onChanged: (_) => field.didChange(
                    parseWorkoutTime(
                      minutesController.text,
                      secondsController.text,
                    ),
                  ),
                ),
                Text(
                  ':',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _TimePartField(
                  controller: secondsController,
                  semanticsLabel: 'Секунды',
                  onChanged: (_) => field.didChange(
                    parseWorkoutTime(
                      minutesController.text,
                      secondsController.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (field.hasError) ...[
            const SizedBox(height: 6),
            Text(
              field.errorText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimePartField extends StatelessWidget {
  final TextEditingController controller;
  final String semanticsLabel;
  final ValueChanged<String> onChanged;

  const _TimePartField({
    required this.controller,
    required this.semanticsLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      textField: true,
      child: SizedBox(
        width: 76,
        child: TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            counterText: '',
            hintText: '00',
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          maxLength: 3,
          onChanged: onChanged,
          onEditingComplete: () {
            final value = int.tryParse(controller.text);
            if (value != null) {
              controller.text = value.toString().padLeft(2, '0');
            }
            FocusScope.of(context).nextFocus();
          },
        ),
      ),
    );
  }
}

class RoundsRepsScoreFields extends StatelessWidget {
  final TextEditingController roundsController;
  final TextEditingController repsController;

  const RoundsRepsScoreFields({
    super.key,
    required this.roundsController,
    required this.repsController,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _IntegerField(
            controller: roundsController,
            label: 'Раунды *',
            suffix: 'рд',
            requiredMessage: 'Введите раунды',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _IntegerField(
            controller: repsController,
            label: 'Доп. повторы',
            suffix: 'повт',
          ),
        ),
      ],
    );
  }
}

class WeightScoreFields extends StatelessWidget {
  final TextEditingController weightController;
  final TextEditingController repsController;

  const WeightScoreFields({
    super.key,
    required this.weightController,
    required this.repsController,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _DecimalField(
            controller: weightController,
            label: 'Вес *',
            suffix: 'кг',
            requiredMessage: 'Введите вес',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _IntegerField(
            controller: repsController,
            label: 'Повторы',
            suffix: 'повт',
          ),
        ),
      ],
    );
  }
}

class RepsScoreField extends StatelessWidget {
  final TextEditingController controller;

  const RepsScoreField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => _IntegerField(
        controller: controller,
        label: 'Количество повторов *',
        suffix: 'повт',
        requiredMessage: 'Введите повторы',
      );
}

class DistanceScoreField extends StatelessWidget {
  final TextEditingController controller;

  const DistanceScoreField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => _DecimalField(
        controller: controller,
        label: 'Дистанция *',
        suffix: 'м',
        requiredMessage: 'Введите дистанцию',
      );
}

class CaloriesScoreField extends StatelessWidget {
  final TextEditingController controller;

  const CaloriesScoreField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => _IntegerField(
        controller: controller,
        label: 'Калории *',
        suffix: 'ккал',
        requiredMessage: 'Введите калории',
      );
}

class TextScoreField extends StatelessWidget {
  final TextEditingController controller;

  const TextScoreField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: _decoration(
        context,
        label: 'Результат *',
        hint: 'например: 5 раундов + 12 берпи',
      ),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Введите результат'
          : null,
    );
  }
}

class NoScoreRequired extends StatelessWidget {
  final String text;
  final Color? accentColor;

  const NoScoreRequired({super.key, required this.text, this.accentColor});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = accentColor ?? colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntegerField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;
  final String? requiredMessage;

  const _IntegerField({
    required this.controller,
    required this.label,
    required this.suffix,
    this.requiredMessage,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _decoration(context, label: label, suffix: suffix),
      validator: (value) {
        if ((value == null || value.trim().isEmpty) && requiredMessage != null) {
          return requiredMessage;
        }
        if (value != null && value.trim().isNotEmpty &&
            parseNonNegativeInt(value) == null) {
          return 'Только целое число';
        }
        return null;
      },
    );
  }
}

class _DecimalField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;
  final String requiredMessage;

  const _DecimalField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.requiredMessage,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
      ],
      decoration: _decoration(context, label: label, suffix: suffix),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return requiredMessage;
        return parseNonNegativeDecimal(value) == null
            ? 'Введите неотрицательное число'
            : null;
      },
    );
  }
}
