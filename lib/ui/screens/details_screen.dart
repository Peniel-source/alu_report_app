import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../logic/auth_cubit.dart';
import '../../logic/incident_cubit.dart';
import '../widgets/widgets.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _clock(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
}

String _stamp(DateTime t) =>
    '${_months[t.month - 1]} ${t.day}, ${t.year} at ${_clock(t)}';

class DetailsScreen extends StatelessWidget {
  final Incident incident;
  const DetailsScreen({super.key, required this.incident});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthCubit>().state.user;

    final live = context.watch<IncidentCubit>().state.all.firstWhere(
          (i) => i.id == incident.id,
      orElse: () => incident,
    );

    final canSupport = me != null &&
        !me.isStaff &&
        live.reporterId != me.uid &&
        live.status != IncidentStatus.resolved;
    final joined = me != null && live.supporterIds.contains(me.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Incident details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _Summary(live),

          if (canSupport) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.read<IncidentCubit>().toggleSupport(live, me),
              icon: Icon(joined ? Icons.check : Icons.groups_outlined),
              label: Text(joined ? 'You are affected too' : 'Me too!'),
            ),
          ],

          const _Label('Status timeline'),
          _Timeline(live),

          const _Label('Description'),
          Text(live.description, style: const TextStyle(height: 1.5)),

          if (live.photoUrl != null) ...[
            const _Label('Attached photo'),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(live.photoUrl!, fit: BoxFit.cover),
            ),
          ],

          if (me != null && me.isStaff && live.status.next != null)
            _StaffPanel(incident: live, staff: me),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primary)),
  );
}

class _Summary extends StatelessWidget {
  final Incident incident;
  const _Summary(this.incident);

  Widget _fact(IconData icon, String text, {Color? ink}) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(children: [
      Icon(icon, size: 16, color: ink ?? Colors.grey.shade600),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(color: ink ?? Colors.grey.shade700))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(incident.category.icon, color: primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(incident.title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(incident.location, style: TextStyle(color: Colors.grey.shade600)),
                      const SizedBox(height: 6),
                      StatusPill(incident.status),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _fact(Icons.calendar_today_outlined, 'Submitted ${_stamp(incident.createdAt)}'),
            _fact(Icons.person_outline, 'Reported by ${incident.reporterName}'),
            _fact(Icons.groups_outlined,
                '${incident.affectedCount} ${incident.affectedCount == 1 ? 'person' : 'people'} affected'),
            incident.isOverdue
                ? _fact(Icons.warning_amber_rounded,
                'Overdue: staff should have responded within ${incident.category.targetHours}h',
                ink: accent)
                : _fact(Icons.timer_outlined,
                'Response target: ${incident.category.targetHours}h for ${incident.category.label}'),
          ],
        ),
      ),
    );
  }
}

class _Timeline extends StatefulWidget {
  final Incident incident;
  const _Timeline(this.incident);

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  late final Stream<List<StatusChange>> _trail;

  @override
  void initState() {
    super.initState();
    _trail = context.read<IncidentCubit>().historyOf(widget.incident.id);
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.incident.status;

    return StreamBuilder<List<StatusChange>>(
      stream: _trail,
      builder: (context, snap) {
        final changes = snap.data ?? [];
        DateTime? whenReached(IncidentStatus s) =>
            changes.where((c) => c.status == s).firstOrNull?.at;

        final stops = IncidentStatus.values;
        final notes = changes.where((c) => (c.note ?? '').trim().isNotEmpty).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < stops.length; i++) ...[
                  _Stop(
                    status: stops[i],
                    reached: stops[i].index <= now.index,
                    isCurrent: stops[i] == now,
                    when: whenReached(stops[i]),
                  ),
                  if (i < stops.length - 1)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(top: 13),
                        height: 2,
                        color: stops[i + 1].index <= now.index
                            ? statusTint(stops[i + 1])
                            : Colors.grey.shade300,
                      ),
                    ),
                ],
              ],
            ),
            for (final change in notes)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(left: BorderSide(color: statusTint(change.status), width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(change.note!),
                    const SizedBox(height: 4),
                    Text('${change.changedBy}, ${_stamp(change.at)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Stop extends StatelessWidget {
  final IncidentStatus status;
  final bool reached;
  final bool isCurrent;
  final DateTime? when;
  const _Stop({required this.status, required this.reached, required this.isCurrent, this.when});

  @override
  Widget build(BuildContext context) {
    final tint = statusTint(status);
    return SizedBox(
      width: 84,
      child: Column(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: reached ? tint : Colors.grey.shade300,
            child: Icon(reached ? Icons.check : Icons.circle,
                size: reached ? 16 : 8, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(status.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: reached ? tint : Colors.grey,
              )),
          if (when != null)
            Text('${_months[when!.month - 1]} ${when!.day}, ${_clock(when!)}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

//change status of report - only staff allowed here
class _StaffPanel extends StatefulWidget {
  final Incident incident;
  final User staff;
  const _StaffPanel({required this.incident, required this.staff});

  @override
  State<_StaffPanel> createState() => _StaffPanelState();
}

class _StaffPanelState extends State<_StaffPanel> {
  final _noteInput = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _noteInput.dispose();
    super.dispose();
  }

  Future<void> _advance() async {
    final next = widget.incident.status.next!;
    final messenger = ScaffoldMessenger.of(context);

    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('Mark as ${next.label}?'),
        content: const Text('Will be forwarded to students'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() => _busy = true);
    await context.read<IncidentCubit>().advance(
      widget.incident,
      widget.staff,
      note: _noteInput.text.trim().isEmpty ? null : _noteInput.text.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _noteInput.clear();
    messenger.showSnackBar(SnackBar(content: Text('Report marked as ${next.label}')));
  }

  @override
  Widget build(BuildContext context) {
    final next = widget.incident.status.next!;
    return Container(
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(children: [
            Icon(Icons.admin_panel_settings_outlined, color: primary),
            SizedBox(width: 8),
            Text('Staff action',
                style: TextStyle(fontWeight: FontWeight.bold, color: primary)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _noteInput,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Note for the students (optional)',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _advance,
            child: _busy
                ? const SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Mark as ${next.label}'),
          ),
        ],
      ),
    );
  }
}