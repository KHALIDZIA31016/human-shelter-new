import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/screen_utils.dart';
import '../../data/models/enums.dart';
import '../../data/models/service_request.dart';
import '../../providers/request_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/visit_widgets.dart';

/// All of the user's visits with live status (upcoming timers, delivered,
/// delayed, missed). Notices about closed orders live in Alerts.
class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

enum _Tab { all, upcoming, done, issues }

class _VisitsScreenState extends State<VisitsScreen> {
  _Tab _tab = _Tab.all;

  bool _match(ServiceRequest r) {
    final s = r.visitState;
    return switch (_tab) {
      _Tab.all => true,
      _Tab.upcoming =>
        s == VisitState.pending ||
            s == VisitState.upcoming ||
            s == VisitState.due,
      _Tab.done => s == VisitState.delivered || s == VisitState.registered,
      _Tab.issues =>
        s == VisitState.delayed ||
            s == VisitState.missed ||
            s == VisitState.rejected ||
            s == VisitState.cancelled,
    };
  }

  @override
  Widget build(BuildContext context) {
    final id = context.watch<SessionProvider>().deviceId;
    final all = context.watch<RequestProvider>().visitsOf(id);
    final items = all.where(_match).toList();
    int count(_Tab t) {
      final prev = _tab;
      _tab = t;
      final n = all.where(_match).length;
      _tab = prev;
      return n;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My visits')),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52.h,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                children: [
                  for (final (t, label) in const [
                    (_Tab.all, 'All'),
                    (_Tab.upcoming, 'Upcoming'),
                    (_Tab.done, 'Delivered'),
                    (_Tab.issues, 'Delayed / closed'),
                  ])
                    Padding(
                      padding: EdgeInsets.only(right: 8.w),
                      child: ChoiceChip(
                        label: Text('$label (${count(t)})'),
                        selected: _tab == t,
                        onSelected: (_) => setState(() => _tab = t),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const EmptyState(
                      icon: Icons.event_available_outlined,
                      title: 'No visits here',
                      message: 'Your requests and their status show up here.',
                    )
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: ScreenUtils.maxContentWidth,
                        ),
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => SizedBox(height: 12.h),
                          itemBuilder: (_, i) => VisitCard(request: items[i]),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
