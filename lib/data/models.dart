import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const staffDomain = '@alueducation.com';
String roleFor(String email) =>
    email.trim().toLowerCase().endsWith(staffDomain) ? 'staff' : 'student';

enum IncidentType {

  facilities('Facilities', Icons.apartment_rounded, 72),
  water('Water', Icons.water_drop, 12),
  electricity('Electricity', Icons.electrical_services, 12),
  safety('Safety', Icons.health_and_safety, 2),
  sanitation('Sanitation', Icons.cleaning_services, 24),
  furniture('Furniture', Icons.chair, 72);

  const IncidentType(this.label, this.icon, this.targetHours);
  final String label;
  final IconData icon;
  final int targetHours;

  static IncidentType fromName(String? name) =>
    values.firstWhere((c) => c.name == name, orElse: () => facilities);
}

enum IncidentStatus {
  submitted('Submitted'),
  inProgress('In Progress'),
  resolved('Resolved');

  const IncidentStatus(this.label);
  final String label;

  IncidentStatus? get next => switch (this) {
    IncidentStatus.submitted => IncidentStatus.inProgress,
    IncidentStatus.inProgress => IncidentStatus.resolved,
    IncidentStatus.resolved => null,
  };

  static IncidentStatus fromName(String? name) =>
    values.firstWhere((s) => s.name == name, orElse: () => submitted);
}

class User {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String? photoUrl;

  const User({
    required this.uid,
    required this.name,
    required this.email,
    this.role = 'student',
    this.photoUrl,
  });

  bool get isStaff => role == 'staff';

  factory User.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return User(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'student',
      photoUrl: data['photoUrl'],
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'email': email, 'role': role};
}

class Incident {
  final String id;
  final String title;
  final String description;
  final IncidentType category;
  final IncidentStatus status;
  final String location;
  final String? photoUrl;
  final String reporterId;
  final String reporterName;
  final DateTime createdAt;
  final List<String> supporterIds; // students who tapped "me too"

  const Incident({
    this.id = '',
    required this.title,
    required this.description,
    required this.category,
    this.status = IncidentStatus.submitted,
    required this.location,
    this.photoUrl,
    required this.reporterId,
    required this.reporterName,
    required this.createdAt,
    this.supporterIds = const [],
  });

  //num of people affected is the reporter plus supporters
  int get affectedCount => 1 + supporterIds.length;

  //overdue
  bool get isOverdue =>
      status == IncidentStatus.submitted && DateTime.now().difference(createdAt).inHours >= category.targetHours;

  bool matches(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q) ||
        location.toLowerCase().contains(q);
  }

  factory Incident.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Incident(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: IncidentType.fromName(data['category']),
      status: IncidentStatus.fromName(data['status']),
      location: data['location'] ?? '',
      photoUrl: data['photoUrl'],
      reporterId: data['reporterId'] ?? '',
      reporterName: data['reporterName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      supporterIds: List<String>.from(data['supporterIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'category': category.name,
    'status': status.name,
    'location': location,
    'photoUrl': photoUrl,
    'reporterId': reporterId,
    'reporterName': reporterName,
    'createdAt': FieldValue.serverTimestamp(),
    'supporterIds': supporterIds,
  };
}

class StatusChange {
  final IncidentStatus status;
  final String changedBy;
  final String? note;
  final DateTime at;

  const StatusChange({
    required this.status,
    required this.changedBy,
    this.note,
    required this.at,
  });

  factory StatusChange.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return StatusChange(
      status: IncidentStatus.fromName(data['status']),
      changedBy: data['changedBy'] ?? '',
      note: data['note'],
      at: (data['at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'status': status.name,
    'changedBy': changedBy,
    'note': note,
    'at': FieldValue.serverTimestamp(),
  };
}

const campusPlaces = {
  'Social Commons': [
    'Food Court',
    'Cafeteria',
    'Learning Labs',
  ],
  'Learning Commons': [
    'Learning Labs',
    'Computer Lab',
    'Library',
    'Leadership Center',
    'Wellness Center',
    'Staff & Reception Area',
  ],
  'Enterprise Commons': [
    'Fab Lab',
    'Learning Labs',
  ],
  'Outdoor Spaces': [
    'Car Park',
    'Collab Street',
    'Entrance',
    'Smartel Area',
    'Smoking Area',
  ],
};