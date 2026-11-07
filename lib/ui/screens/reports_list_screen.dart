import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../logic/incident_cubit.dart';
import '../widgets/widgets.dart';
import 'details_screen.dart';

class ReportsListScreen extends StatefulWidget {
  const ReportsListScreen({super.key});

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<ReportsListScreen> {
  final _lookup = TextEditingController();

  @override
  void dispose() {
    _lookup.dispose();
    super.dispose();
  }

  void _resetAll(IncidentCubit cubit) {
    _lookup.clear();
    cubit.search('');
    cubit.filterCategory(null);
    cubit.filterStatus(null);
  }

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<IncidentCubit>().state;
    final cubit = context.read<IncidentCubit>();
    final shown = reports.visible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Campus reports',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: primary)),
              const SizedBox(height: 12),
              TextField(
                controller: _lookup,
                onChanged: cubit.search,
                decoration: InputDecoration(
                  hintText: 'Search title, description or place',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _lookup.text.isEmpty
                      ? null
                      : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _lookup.clear();
                      cubit.search('');
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        //filters for thr categories
        _ChipStrip(children: [
          _filterChip('All', reports.category == null, () => cubit.filterCategory(null)),
          for (final type in IncidentType.values)
            _filterChip(
              type.label,
              reports.category == type,
                  () => cubit.filterCategory(reports.category == type ? null : type),
              icon: type.icon,
            ),
        ]),
        const SizedBox(height: 8),

        _ChipStrip(children: [
          _filterChip('Any status', reports.status == null, () => cubit.filterStatus(null)),
          for (final status in IncidentStatus.values)
            _filterChip(
              status.label,
              reports.status == status,
                  () => cubit.filterStatus(reports.status == status ? null : status),
            ),
        ]),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
          child: Row(
            children: [
              Text('${shown.length} report${shown.length == 1 ? '' : 's'}',
                  style: TextStyle(color: Colors.grey.shade600)),
              const Spacer(),
              TextButton.icon(
                onPressed: cubit.toggleSort,
                icon: const Icon(Icons.sort, size: 18),
                label: Text(reports.sortByImpact ? 'Most affected' : 'Newest'),
              ),
            ],
          ),
        ),

        Expanded(
          child: reports.loading
              ? const Center(child: CircularProgressIndicator())
              : shown.isEmpty
              ? _NothingHere(
            hasAnyReports: reports.all.isNotEmpty,
            onReset: () => _resetAll(cubit),
          )
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            itemCount: shown.length,
            itemBuilder: (context, i) => ReportTile(
              incident: shown[i],
              onTap: () => openWithReports(context, DetailsScreen(incident: shown[i])),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _filterChip(String text, bool on, VoidCallback tap, {IconData? icon}) {
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(text),
      avatar: icon == null
          ? null
          : Icon(icon, size: 16, color: on ? Colors.white : primary),
      selected: on,
      onSelected: (_) => tap(),
      showCheckmark: false,
      selectedColor: primary,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(color: on ? Colors.white : primary, fontWeight: FontWeight.w600),
      side: BorderSide(color: on ? primary : Colors.grey.shade300),
      shape: const StadiumBorder(),
    ),
  );
}

class _ChipStrip extends StatelessWidget {
  final List<Widget> children;
  const _ChipStrip({required this.children});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 40,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: children,
    ),
  );
}

class _NothingHere extends StatelessWidget {
  final bool hasAnyReports;
  final VoidCallback onReset;
  const _NothingHere({required this.hasAnyReports, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              hasAnyReports
                  ? 'No matche'
                  : 'No reports on campus yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (hasAnyReports)
              TextButton(onPressed: onReset, child: const Text('Clear')),
          ],
        ),
      ),
    );
  }
}