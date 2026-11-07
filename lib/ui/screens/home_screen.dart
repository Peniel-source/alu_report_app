import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../logic/auth_cubit.dart';
import '../../logic/incident_cubit.dart';
import '../widgets/widgets.dart';
import 'details_screen.dart';
import 'profile_screen.dart';
import 'report_form_screen.dart';
import 'reports_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeTab = 0;

  void _openForm() => openWithReports(context, const ReportFormScreen());
  void _jumpTo(int tab) => setState(() => _activeTab = tab);

  @override
  Widget build(BuildContext context) {
    final barSpot = _activeTab == 2 ? 3 : _activeTab;

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _activeTab,
          children: [
            _Overview(onSeeAll: () => _jumpTo(1), onReport: _openForm),
            const ReportsListScreen(),
            const ProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: barSpot,
        onDestinationSelected: (spot) {
          if (spot == 2) {
            _openForm();
            return;
          }
          _jumpTo(spot == 3 ? 2 : spot);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description),
              label: 'Reports'),
          NavigationDestination(
              icon: Icon(Icons.add_circle, size: 40, color: accent), label: 'Report'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  final VoidCallback onSeeAll;
  final VoidCallback onReport;
  const _Overview({required this.onSeeAll, required this.onReport});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthCubit>().state.user;
    final reports = context.watch<IncidentCubit>().state;

    if (me == null) return const SizedBox.shrink();
    if (reports.loading) return const Center(child: CircularProgressIndicator());

    final scope = me.isStaff ? reports.all : reports.reportedBy(me.uid);
    int tally(IncidentStatus s) => scope.where((i) => i.status == s).length;

    final firstName = me.name.isEmpty ? 'there' : me.name.split(' ').first;


    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        //greeting row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, $firstName',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: primary)),
                  const SizedBox(height: 4),
                  Text(
                    me.isStaff
                        ? 'Here is what needs attention on campus'
                        : 'Make your campus better.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            FaceBadge(name: me.name, photoUrl: me.photoUrl),
          ],
        ),
        const SizedBox(height: 20),

        _HeroBanner(
          isStaff: me.isStaff,
          overdue: reports.overdueCount,
          onTap: me.isStaff ? onSeeAll : onReport,
        ),
        const SizedBox(height: 24),

        const Text('Report summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            _TallyTile(
              label: me.isStaff ? 'All reports' : 'My reports',
              value: scope.length,
              icon: Icons.description_outlined,
              tint: primary,
            ),
            const SizedBox(width: 8),
            me.isStaff
                ? _TallyTile(
                label: 'Overdue',
                value: reports.overdueCount,
                icon: Icons.warning_amber_rounded,
                tint: Colors.red)
                : _TallyTile(
                label: 'Submitted',
                value: tally(IncidentStatus.submitted),
                icon: Icons.outbox_outlined,
                tint: statusTint(IncidentStatus.submitted)),
            const SizedBox(width: 8),
            _TallyTile(
              label: 'In progress',
              value: tally(IncidentStatus.inProgress),
              icon: Icons.schedule,
              tint: statusTint(IncidentStatus.inProgress),
            ),
            const SizedBox(width: 8),
            _TallyTile(
              label: 'Resolved',
              value: tally(IncidentStatus.resolved),
              icon: Icons.check_circle_outline,
              tint: statusTint(IncidentStatus.resolved),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            const Expanded(
              child: Text('Recent reports',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            TextButton(onPressed: onSeeAll, child: const Text('See all')),
          ],
        ),
        const SizedBox(height: 8),
        if (scope.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              me.isStaff
                  ? 'No reports yet'
                  : 'No reports yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ...scope.take(3).map((incident) => ReportTile(
          incident: incident,
          onTap: () => openWithReports(context, DetailsScreen(incident: incident)),
        )),
      ],
    );
  }
}


class _HeroBanner extends StatelessWidget {
  final bool isStaff;
  final int overdue;
  final VoidCallback onTap;
  const _HeroBanner({required this.isStaff, required this.overdue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final headline = isStaff
        ? (overdue > 0 ? '$overdue report${overdue == 1 ? '' : 's'} overdue' : 'All caught up')
        : 'Is there any issue?';
    final subline = isStaff
        ? 'Reports waiting longer than their response time'
        : "Report it so we can improve ALU's environment";
    final action = isStaff ? 'Check reports' : 'Report an issue';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Text(headline,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(subline, style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 16),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: accent,
                      child: Icon(isStaff ? Icons.visibility : Icons.add,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(action,
                          style: const TextStyle(
                              color: primary, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const Icon(Icons.chevron_right, color: primary),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TallyTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color tint;
  const _TallyTile({required this.label, required this.value, required this.icon, required this.tint});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: tint),
            const SizedBox(height: 6),
            Text('$value',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: primary)),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}