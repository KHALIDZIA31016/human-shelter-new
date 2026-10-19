import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/complaint.dart';
import '../../data/models/enums.dart';
import '../../providers/complaint_provider.dart';
import '../../widgets/admin_header.dart';
import '../../widgets/app_widgets.dart';
import 'complaint_detail_screen.dart';

void _open(BuildContext c, Complaint x) =>
    AppRouter.push(c, AppRoutes.complaint, x.id);

/// Admin: every complaint, filterable by status.
class AdminComplaintsTab extends StatefulWidget {
  const AdminComplaintsTab({super.key});

  @override
  State<AdminComplaintsTab> createState() => _AdminComplaintsTabState();
}

class _AdminComplaintsTabState extends State<AdminComplaintsTab> {
  ComplaintStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final all = context.watch<ComplaintProvider>().all;
    final items = _filter == null
        ? all
        : all.where((c) => c.status == _filter).toList();
    return Column(
      children: [
        AdminHeader(
          icon: Icons.report_gmailerrorred_rounded,
          title: 'Complaints',
          subtitle: () {
            final open = all
                .where((c) => c.status == ComplaintStatus.open)
                .length;
            return open == 0 ? 'No new complaints' : '$open new to review';
          }(),
          tiles: [
            HeaderTile('All', all.length),
            for (final s in ComplaintStatus.values)
              HeaderTile(s.label, all.where((c) => c.status == s).length),
          ],
          selected: _filter == null ? 0 : _filter!.index + 1,
          onSelected: (i) => setState(
            () => _filter = i == 0 ? null : ComplaintStatus.values[i - 1],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const EmptyState(
                  icon: Icons.verified_user_outlined,
                  title: 'No complaints',
                  message: 'Complaints from users about shelters appear here.',
                )
              : _list(
                  items,
                  (c) => ComplaintCard(
                    complaint: c,
                    forAdmin: true,
                    onTap: () => _open(context, c),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Shelter: neutral verification requests from the admin.
class ShelterVerificationTab extends StatelessWidget {
  const ShelterVerificationTab({super.key, required this.shelterId});

  final String shelterId;

  @override
  Widget build(BuildContext context) {
    final items = context.watch<ComplaintProvider>().forShelter(shelterId);
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.fact_check_outlined,
        title: 'No verification requests',
        message:
            'If the admin needs you to confirm a service record, it will appear here.',
      );
    }
    return _list(
      items,
      (c) => ComplaintCard(
        complaint: c,
        neutral: true,
        onTap: () => _open(context, c),
      ),
    );
  }
}

Widget _list(List<Complaint> items, Widget Function(Complaint) build) {
  return Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: ScreenUtils.maxContentWidth),
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
        itemCount: items.length,
        separatorBuilder: (_, _) => SizedBox(height: 12.h),
        itemBuilder: (_, i) => build(items[i]),
      ),
    ),
  );
}
