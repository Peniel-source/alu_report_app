import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../logic/auth_cubit.dart';
import '../../logic/incident_cubit.dart';
import '../widgets/widgets.dart';
import 'details_screen.dart';

class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _draftForm = GlobalKey<FormState>();
  final _titleInput = TextEditingController();
  final _detailsInput = TextEditingController();
  final _roomInput = TextEditingController();
  IncidentType? _pickedType;
  String? _pickedSpot;
  File? _snapshot;
  bool _triedOnce = false;

  @override
  void dispose() {
    _titleInput.dispose();
    _detailsInput.dispose();
    _roomInput.dispose();
    super.dispose();
  }
  bool get _needsRoom => _pickedSpot?.endsWith('Learning Labs') ?? false;

  String? get _fullSpot {
    if (_pickedSpot == null) return null;
    if (!_needsRoom) return _pickedSpot;
    final room = _roomInput.text.trim();
    return room.isEmpty ? null : '$_pickedSpot ($room)';
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(sheet, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(sheet, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return;

    // shrink the photos before upload
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 70,
    );
    if (picked != null) setState(() => _snapshot = File(picked.path));
  }

  Future<void> _send() async {
    setState(() => _triedOnce = true);
    final fieldsOk = _draftForm.currentState!.validate();
    if (!fieldsOk || _pickedType == null) return;

    final me = context.read<AuthCubit>().state.user;
    if (me == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final sent = await context.read<IncidentCubit>().submit(
      title: _titleInput.text,
      description: _detailsInput.text,
      category: _pickedType!,
      location: _fullSpot!,
      reporter: me,
      photo: _snapshot,
    );

    if (sent) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you!')),
      );
    }
  }

  Widget _heading(String text, {String? extra}) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text.rich(TextSpan(
      text: text,
      style: const TextStyle(fontWeight: FontWeight.w600, color: primary),
      children: [
        if (extra != null)
          TextSpan(
            text: '  $extra',
            style: TextStyle(fontWeight: FontWeight.normal, color: Colors.grey.shade600),
          ),
      ],
    )),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an incident')),
      body: Form(
        key: _draftForm,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            _heading('Select a category'),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.25,
              children: IncidentType.values
                  .map((type) => _TypeTile(
                type: type,
                chosen: type == _pickedType,
                onTap: () => setState(() => _pickedType = type),
              ))
                  .toList(),
            ),
            if (_triedOnce && _pickedType == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Pick a category',
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
              ),

            _heading('Title'),
            TextFormField(
              controller: _titleInput,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Briefly describe the issue'),
              validator: (v) =>
              (v ?? '').trim().length < 5 ? 'Give it a clearer title' : null,
            ),

            _heading('Description'),
            TextFormField(
              controller: _detailsInput,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'What happened?',
              ),
              validator: (v) => (v ?? '').trim().length < 15
                  ? 'Add more details'
                  : null,
            ),

            _heading('Location'),
            DropdownButtonFormField<String>(
              initialValue: _pickedSpot,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.place_outlined)),
              hint: const Text('Where is it?'),
              items: campusPlaces.entries.expand((entry) {
                return [
                  DropdownMenuItem<String>(
                    enabled: false,
                    value: null,
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                  ...entry.value.map(
                        (spot) => DropdownMenuItem<String>(
                      value: '${entry.key} · $spot',
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: Text(spot),
                      ),
                    ),
                  ),
                ];
              }).toList(),
              onChanged: (spot) => setState(() => _pickedSpot = spot),
              validator: (v) => v == null ? 'Pick a location' : null,
            ),

            // "Me too" should appear when the user selects the category and location
            if (_needsRoom) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _roomInput,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Which classroom?',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                ),
                onChanged: (_) => setState(() {}), // refresh the "me too" check
                validator: (v) =>
                _needsRoom && (v ?? '').trim().isEmpty ? 'Which Learning Lab?' : null,
              ),
            ],

            if (_pickedType != null && _fullSpot != null)
              _AlreadyReported(type: _pickedType!, spot: _fullSpot!),

            _heading('Add a photo', extra: '(optional)'),
            _snapshot == null
                ? InkWell(
              onTap: _choosePhoto,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_outlined, color: primary),
                    const SizedBox(height: 6),
                    Text('Tap to add a photo', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            )
                : Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(_snapshot!,
                      height: 180, width: double.infinity, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _snapshot = null),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),
            BlocBuilder<IncidentCubit, IncidentState>(
              buildWhen: (before, after) =>
              before.submitting != after.submitting || before.error != after.error,
              builder: (context, reports) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (reports.error != null && !reports.submitting)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(reports.error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  FilledButton(
                    onPressed: reports.submitting ? null : _send,
                    child: reports.submitting
                        ? const SizedBox(
                        width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Submit report'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  final IncidentType type;
  final bool chosen;
  final VoidCallback onTap;
  const _TypeTile({required this.type, required this.chosen, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ink = chosen ? Colors.white : primary;
    return Material(
      color: chosen ? primary : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(type.icon, color: ink),
            const SizedBox(height: 6),
            Text(type.label,
                style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}


class _AlreadyReported extends StatelessWidget {
  final IncidentType type;
  final String spot;
  const _AlreadyReported({required this.type, required this.spot});

  @override
  Widget build(BuildContext context) {
    final matches = context.watch<IncidentCubit>().state.similarTo(type, spot);
    final me = context.watch<AuthCubit>().state.user;
    if (matches.isEmpty || me == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${matches.length} open report'
                      '${matches.length == 1 ? ' already matches' : 's already match'} this. '
                      'Join this report?',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...matches.take(3).map((incident) {
            final mine = incident.reporterId == me.uid;
            final joined = incident.supporterIds.contains(me.uid);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(incident.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                  '${incident.affectedCount} affected · ${howLongAgo(incident.createdAt)}'),
              onTap: () => openWithReports(context, DetailsScreen(incident: incident)),
              trailing: mine
                  ? const Text('Yours')
                  : TextButton(
                onPressed: () =>
                    context.read<IncidentCubit>().toggleSupport(incident, me),
                child: Text(joined ? 'Joined' : 'Me too'),
              ),
            );
          }),
        ],
      ),
    );
  }
}