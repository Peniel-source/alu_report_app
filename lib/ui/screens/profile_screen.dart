import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../app.dart';
import '../../data/models.dart';
import '../../logic/auth_cubit.dart';
import '../../logic/incident_cubit.dart';
import '../widgets/widgets.dart';
import 'details_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _joinedView = false; // false for my reports, true for reports I joined

  Future<void> _leave() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (sure == true && mounted) context.read<AuthCubit>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final me = auth.user;
    final reports = context.watch<IncidentCubit>().state;
    if (me == null) return const SizedBox.shrink();

    final filed = reports.reportedBy(me.uid);
    final joined = reports.all.where((i) => i.supporterIds.contains(me.uid)).toList();
    final fixed = filed.where((i) => i.status == IncidentStatus.resolved).length;
    final shown = _joinedView ? joined : filed;


    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('My profile',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: primary)),
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: primary),
              tooltip: 'Sign out',
              onPressed: _leave,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Identity card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: auth.loading
                      ? null
                      : () async {
                    final photo = await pickPhoto(context, maxWidth: 512);
                    if (photo != null && context.mounted) {
                      context.read<AuthCubit>().changeAvatar(photo);
                    }
                  },
                  child: Stack(
                    children: [
                      FaceBadge(name: me.name, photoUrl: me.photoUrl, radius: 32),
                      const Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: accent,
                          child: Icon(Icons.camera_alt, size: 12, color: Colors.white),
                        ),
                      ),
                      if (auth.loading)
                        const Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(me.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: (me.isStaff ? accent : primary).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(me.isStaff ? 'Staff' : 'Student',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: me.isStaff ? accent : primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(me.email, style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (auth.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(auth.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 12),

        Row(children: [
          _Stat('Filed', filed.length),
          const SizedBox(width: 8),
          _Stat('Joined', joined.length),
          const SizedBox(width: 8),
          _Stat('Resolved', fixed),
        ]),
        const SizedBox(height: 20),

        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Filed by me'), icon: Icon(Icons.edit_note)),
            ButtonSegment(value: true, label: Text('Me too'), icon: Icon(Icons.groups_outlined)),
          ],
          selected: {_joinedView},
          showSelectedIcon: false,
          onSelectionChanged: (pick) => setState(() => _joinedView = pick.first),
        ),
        const SizedBox(height: 12),

        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              _joinedView
                  ? "No reports. You can open someone's report and tap \"Me too\"."
                  : "You haven't filed any reports yet.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ...shown.map((incident) => ReportTile(
          incident: incident,
          onTap: () => openWithReports(context, DetailsScreen(incident: incident)),
        )),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: [
        Text('$value',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primary)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ]),
    ),
  );
}