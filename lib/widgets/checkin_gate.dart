import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../core/utils/screen_utils.dart';
import '../data/models/enums.dart';
import '../data/models/service_request.dart';
import '../providers/request_provider.dart';
import '../providers/session_provider.dart';
import 'app_widgets.dart';

/// Covers the whole app in user mode once the approved check-in time is up.
/// It cannot be dismissed: the user must check in or cancel.
class CheckInGate extends StatefulWidget {
  const CheckInGate({super.key, required this.child});

  final Widget child;

  @override
  State<CheckInGate> createState() => _CheckInGateState();
}

class _CheckInGateState extends State<CheckInGate> {
  Timer? _timer;
  bool _confirmCancel = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Re-evaluate every second so the card appears the moment time is up.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    final err = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _confirmCancel = false;
    });
    if (err != null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(err)));
    }
  }

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final reqs = context.watch<RequestProvider>();
    final due = session.persona == Persona.needy
        ? reqs.frozenBy(session.deviceId)
        : null;
    if (due == null) return widget.child;
    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          widget.child,
          const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Colors.black54),
          ),
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 22.w),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 420.w),
                      child: _card(due),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: EdgeInsets.symmetric(vertical: 7.h),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16.sp, color: AppColors.primary),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5.sp,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutral,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _card(ServiceRequest r) {
    final at = r.arrivalAt!;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 22.h, horizontal: 20.w),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, Color(0xFF134E4A)],
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.alarm_on_rounded,
                    color: Colors.white,
                    size: 32.sp,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  'Time to check in',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Your shelter bed is waiting',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20.r, 12.r, 20.r, 20.r),
            child: Column(
              children: [
                _row(Icons.home_work_rounded, 'Shelter', r.targetName),
                _row(
                  Icons.calendar_today_rounded,
                  'Day',
                  _days[at.weekday - 1],
                ),
                _row(Icons.schedule_rounded, 'Check-in time', fmtDateTime(at)),
                _row(
                  Icons.badge_outlined,
                  'Ask for',
                  (r.contactPerson ?? '').isEmpty ? '—' : r.contactPerson!,
                ),
                SizedBox(height: 14.h),
                if (_confirmCancel) ...[
                  Text(
                    'Cancel this registration? Your bed will be released and '
                    'you can apply again after 1 hour.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      color: AppColors.rejected,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Back',
                          outlined: true,
                          onPressed: _busy
                              ? null
                              : () => setState(() => _confirmCancel = false),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: AppButton(
                          label: 'Yes, cancel',
                          color: AppColors.rejected,
                          loading: _busy,
                          onPressed: () => _run(
                            () => context
                                .read<RequestProvider>()
                                .userCancelCheckIn(r.id),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Cancel',
                          outlined: true,
                          color: AppColors.rejected,
                          onPressed: _busy
                              ? null
                              : () => setState(() => _confirmCancel = true),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          label: 'I checked in',
                          icon: Icons.how_to_reg_rounded,
                          loading: _busy,
                          onPressed: () => _run(
                            () => context.read<RequestProvider>().userCheckIn(
                              r.id,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
