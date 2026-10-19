import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/screen_utils.dart';
import '../core/utils/validators.dart';
import '../data/models/enums.dart';

/// Centers content and caps its width on tablets.
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.child,
    this.padding,
    this.scroll = true,
  });

  final Widget child;
  final EdgeInsets? padding;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final pad = padding ?? EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h);
    final content = Padding(padding: pad, child: child);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: ScreenUtils.maxContentWidth,
        ),
        child: scroll ? SingleChildScrollView(child: content) : content,
      ),
    );
  }
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.outlined = false,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool outlined;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = outlined ? (color ?? AppColors.primary) : Colors.white;
    final child = loading
        ? SizedBox(
            width: 20.r,
            height: 20.r,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20.sp),
                SizedBox(width: 8.w),
              ],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );
    final action = loading ? null : onPressed;
    final size = Size.fromHeight(52.h);
    return outlined
        ? OutlinedButton(
            onPressed: action,
            style: OutlinedButton.styleFrom(
              minimumSize: size,
              foregroundColor: color,
              side: BorderSide(color: color ?? AppColors.primary),
            ),
            child: child,
          )
        : FilledButton(
            onPressed: action,
            style: FilledButton.styleFrom(
              minimumSize: size,
              backgroundColor: color,
            ),
            child: child,
          );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.textInputAction,
    this.digitsOnly = false,
    this.enabled = true,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final bool digitsOnly;
  final bool enabled;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        obscureText: obscureText,
        validator: validator,
        keyboardType: keyboardType,
        maxLines: obscureText ? 1 : maxLines,
        maxLength: maxLength,
        textInputAction:
            textInputAction ??
            (maxLines > 1 ? TextInputAction.newline : TextInputAction.next),
        textCapitalization:
            keyboardType == null || keyboardType == TextInputType.text
            ? TextCapitalization.sentences
            : TextCapitalization.none,
        inputFormatters: digitsOnly
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon),
          counterText: '',
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final ReviewStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      ReviewStatus.pending => (AppColors.pending, Icons.hourglass_top_rounded),
      ReviewStatus.approved => (AppColors.approved, Icons.check_circle_rounded),
      ReviewStatus.rejected => (AppColors.rejected, Icons.cancel_rounded),
      ReviewStatus.cancelled => (AppColors.neutral, Icons.block_rounded),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 4.w),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(32.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56.sp,
              color: AppColors.neutral.withValues(alpha: 0.6),
            ),
            SizedBox(height: 12.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700),
            ),
            if (message != null) ...[
              SizedBox(height: 6.h),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.sp, color: AppColors.neutral),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 16.h, bottom: 8.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.icon, this.label, this.value, {super.key});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18.sp, color: AppColors.neutral),
          SizedBox(width: 10.w),
          SizedBox(
            width: 104.w,
            child: Text(
              label,
              style: TextStyle(fontSize: 13.sp, color: AppColors.neutral),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Colored banner for inline guidance / status messages.
class Callout extends StatelessWidget {
  const Callout({
    super.key,
    required this.icon,
    required this.text,
    this.color = AppColors.primary,
    this.title,
  });

  final IconData icon;
  final String text;
  final String? title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.sp,
                    ),
                  ),
                Text(text, style: TextStyle(fontSize: 13.5.sp, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CountStepper extends StatelessWidget {
  const CountStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.step = 1,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Decrease',
            onPressed: value - step >= min
                ? () => onChanged(value - step)
                : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 36.w,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Increase',
            onPressed: value + step <= max
                ? () => onChanged(value + step)
                : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

// ---- dialogs & sheets ---------------------------------------------------

Future<void> showSuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.check_circle_rounded,
  String button = 'Got it',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 26.h),
            color: AppColors.primary.withValues(alpha: 0.08),
            child: Center(
              child: Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                child: Container(
                  width: 62.r,
                  height: 62.r,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 34.sp),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(22.w, 20.h, 22.w, 22.h),
            child: Column(
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    height: 1.4,
                    color: AppColors.neutral,
                  ),
                ),
                SizedBox(height: 20.h),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                    ),
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
                    child: Text(button),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Asks for a mandatory rejection reason. Returns null if dismissed.
Future<String?> showReasonSheet(
  BuildContext context, {
  required String title,
  List<String> quickReasons = const [],
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReasonSheet(title: title, quick: quickReasons),
  );
}

class _ReasonSheet extends StatefulWidget {
  const _ReasonSheet({required this.title, required this.quick});

  final String title;
  final List<String> quick;

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  final _ctrl = TextEditingController();
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20.w,
        0,
        20.w,
        MediaQuery.viewInsetsOf(context).bottom + 20.h,
      ),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 4.h),
            Text(
              'The reason is sent to the applicant, so keep it clear.',
              style: TextStyle(fontSize: 13.sp, color: AppColors.neutral),
            ),
            SizedBox(height: 12.h),
            if (widget.quick.isNotEmpty)
              Wrap(
                spacing: 8.w,
                runSpacing: 4.h,
                children: [
                  for (final q in widget.quick)
                    ActionChip(label: Text(q), onPressed: () => _ctrl.text = q),
                ],
              ),
            SizedBox(height: 12.h),
            AppTextField(
              controller: _ctrl,
              label: 'Reason',
              maxLines: 3,
              maxLength: 300,
              validator: Validators.reason,
            ),
            AppButton(
              label: 'Confirm rejection',
              icon: Icons.close_rounded,
              color: AppColors.rejected,
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, _ctrl.text.trim());
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
