import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/screen_utils.dart';
import '../../providers/request_provider.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/approval_report.dart';

/// Every official approval report this shelter has issued.
class ApprovalReportsScreen extends StatelessWidget {
  const ApprovalReportsScreen({super.key, required this.shelterId});

  final String shelterId;

  @override
  Widget build(BuildContext context) {
    final reports = approvalReports(
      context.watch<RequestProvider>().sentTo(shelterId),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Approval reports')),
      body: SafeArea(
        child: reports.isEmpty
            ? const EmptyState(
                icon: Icons.verified_outlined,
                title: 'No reports yet',
                message:
                    'An official report is saved here each time you approve a stay.',
              )
            : PageBody(
                child: Column(
                  children: [
                    for (final r in reports) ...[
                      ApprovalReportCard(request: r),
                      SizedBox(height: 14.h),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
