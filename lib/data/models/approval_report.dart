import '../../core/utils/formatters.dart';
import 'enums.dart';
import 'registration.dart';
import 'service_request.dart';

/// Approved stays that carry an official approval report, newest first.
List<ServiceRequest> approvalReports(Iterable<ServiceRequest> all) {
  final out =
      [
        for (final r in all)
          if (r.type == RequestType.stay &&
              r.status == ReviewStatus.approved &&
              r.arrivalAt != null)
            r,
      ]..sort(
        (a, b) =>
            (b.decidedAt ?? b.createdAt).compareTo(a.decidedAt ?? a.createdAt),
      );
  return out;
}

String approvalReportNo(ServiceRequest r) =>
    'AR-${(r.id.length > 6 ? r.id.substring(r.id.length - 6) : r.id).toUpperCase()}';

/// Plain-text copy of the report (used for the admin notification).
String approvalReportText(ServiceRequest r, Registration? person) {
  final b = StringBuffer()
    ..writeln('OFFICIAL APPROVAL REPORT · ${approvalReportNo(r)}')
    ..writeln('Full name: ${person?.name ?? r.requesterName}')
    ..writeln(
      'Phone: ${(person?.phone ?? '').isEmpty ? r.phone : person!.phone}',
    )
    ..writeln('Approved shelter: ${r.targetName}')
    ..writeln('Arrival time: ${fmtDateTime(r.arrivalAt!)}')
    ..writeln('Report to on arrival: ${r.contactPerson ?? '—'}')
    ..write(
      'Notice: ${(r.decisionNote ?? '').isEmpty ? 'None' : r.decisionNote}',
    );
  return b.toString();
}
