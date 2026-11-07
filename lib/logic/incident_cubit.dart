import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models.dart';
import '../data/repositories.dart';

class IncidentState {
  final List<Incident> all;
  final String query;
  final IncidentType? category;
  final IncidentStatus? status;
  final bool sortByImpact; // most affected first
  final bool loading;
  final bool submitting;
  final String? error;

  const IncidentState({
    this.all = const [],
    this.query = '',
    this.category,
    this.status,
    this.sortByImpact = false,
    this.loading = true,
    this.submitting = false,
    this.error,
  });

  List<Incident> get visible {
    final list = all
        .where((i) =>
    i.matches(query) &&
        (category == null || i.category == category) &&
        (status == null || i.status == status))
        .toList();
    if (sortByImpact) {
      list.sort((a, b) => b.affectedCount.compareTo(a.affectedCount));
    }
    return list;
  }

  List<Incident> reportedBy(String uid) =>
      all.where((i) => i.reporterId == uid).toList();

  int get overdueCount => all.where((i) => i.isOverdue).length;

  //all the reports with "me too"
  List<Incident> similarTo(IncidentType type, String location) {
    final loc = location.toLowerCase().trim();
    if (loc.isEmpty) return [];
    return all
        .where((i) =>
    i.status != IncidentStatus.resolved &&
        i.category == type &&
        i.location.toLowerCase().trim() == loc)
        .toList();
  }

  IncidentState copyWith({
    List<Incident>? all,
    String? query,
    IncidentType? category,
    bool clearCategory = false,
    IncidentStatus? status,
    bool clearStatus = false,
    bool? sortByImpact,
    bool? loading,
    bool? submitting,
    String? error,
    bool clearError = false,
  }) {
    return IncidentState(
      all: all ?? this.all,
      query: query ?? this.query,
      category: clearCategory ? null : (category ?? this.category),
      status: clearStatus ? null : (status ?? this.status),
      sortByImpact: sortByImpact ?? this.sortByImpact,
      loading: loading ?? this.loading,
      submitting: submitting ?? this.submitting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class IncidentCubit extends Cubit<IncidentState> {
  final IncidentRepository _repo;
  StreamSubscription? _sub;

  IncidentCubit(this._repo) : super(const IncidentState()) {
    _sub = _repo.watchAll().listen(
          (list) => emit(state.copyWith(all: list, loading: false)),
      onError: (_) => emit(state.copyWith(
        loading: false,
        error: 'Reports failed to load',
      )),
    );
  }

  // search, filter, sort- no firebse calls here
  void search(String text) => emit(state.copyWith(query: text));

  void filterCategory(IncidentType? type) =>
      emit(state.copyWith(category: type, clearCategory: type == null));

  void filterStatus(IncidentStatus? status) =>
      emit(state.copyWith(status: status, clearStatus: status == null));

  void toggleSort() => emit(state.copyWith(sortByImpact: !state.sortByImpact));

  Future<bool> submit({
    required String title,
    required String description,
    required IncidentType category,
    required String location,
    required User reporter,
    File? photo,
  }) async {
    emit(state.copyWith(submitting: true, clearError: true));
    try {
      await _repo.submit(
        Incident(
          title: title.trim(),
          description: description.trim(),
          category: category,
          location: location,
          reporterId: reporter.uid,
          reporterName: reporter.name,
          createdAt: DateTime.now(),
        ),
        photo,
      );
      emit(state.copyWith(submitting: false));
      return true;
    } catch (_) {
      emit(state.copyWith(
        submitting: false,
        error: 'Submit faied. Try again',
      ));
      return false;
    }
  }

  //only staff can update the status
  Future<void> advance(Incident incident, User staff, {String? note}) async {
    if (!staff.isStaff) return;
    try {
      await _repo.advanceStatus(incident, staff.name, note: note);
    } catch (_) {
      emit(state.copyWith(error: 'update failed'));
    }
  }

  //you can do "Me too"but not for your own report
  Future<void> toggleSupport(Incident incident, User user) async {
    if (incident.reporterId == user.uid) return;
    await _repo.toggleSupport(incident, user.uid);
  }

  Stream<List<StatusChange>> historyOf(String incidentId) =>
      _repo.watchHistory(incidentId);

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}