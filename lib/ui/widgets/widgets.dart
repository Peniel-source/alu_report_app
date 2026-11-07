import 'package:flutter/material.dart';
import '../../app.dart';
import '../../data/models.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

Color statusTint(IncidentStatus status) => switch (status) {
  IncidentStatus.submitted => accent,
  IncidentStatus.inProgress => primary,
  IncidentStatus.resolved => const Color(0xFF2E9E5B),
};

//how long ago was the issue reported
String howLongAgo(DateTime moment) {
  final gap = DateTime.now().difference(moment);
  if (gap.inMinutes < 1) return 'just now';
  if (gap.inMinutes < 60) return '${gap.inMinutes}m ago';
  if (gap.inHours < 24) return '${gap.inHours}h ago';
  if (gap.inDays < 7) return '${gap.inDays}d ago';
  return '${moment.day}/${moment.month}/${moment.year}';
}

class StatusPill extends StatelessWidget {
  final IncidentStatus status;
  const StatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final tint = statusTint(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: tint, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

//a card for every list of reports.
class ReportTile extends StatelessWidget {
  final Incident incident;
  final VoidCallback? onTap;
  const ReportTile({super.key, required this.incident, this.onTap});

  @override
  Widget build(BuildContext context) {
    final faded = TextStyle(color: Colors.grey.shade600, fontSize: 13);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _Thumbnail(incident),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(incident.location, style: faded),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(howLongAgo(incident.createdAt), style: faded),
                        //show number of people affected
                        if (incident.affectedCount > 1) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.groups_outlined, size: 15, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('${incident.affectedCount}', style: faded),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusPill(incident.status),
                  if (incident.isOverdue) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Overdue',
                      style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final Incident incident;
  const _Thumbnail(this.incident);

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      child: Icon(incident.category.icon, color: Theme.of(context).colorScheme.primary),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        height: 64,
        child: incident.photoUrl == null
            ? fallback
            : Image.network(
          incident.photoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}

class FaceBadge extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;
  const FaceBadge({super.key, required this.name, this.photoUrl, this.radius = 24});

  String get _initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: primary,
    foregroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
    child: Text(
      _initials,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: radius * 0.6,
      ),
    ),
  );
}

Future<File?> pickPhoto(BuildContext context, {double maxWidth = 1280}) async {
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
  if (source == null) return null;

  final picked = await ImagePicker()
      .pickImage(source: source, maxWidth: maxWidth, imageQuality: 70);
  return picked == null ? null : File(picked.path);
}