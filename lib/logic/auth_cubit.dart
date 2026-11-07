import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

enum AuthStatus { unknown, loggedOut, loggedIn }

class AuthState {
  final AuthStatus status;
  final User? user;
  final bool loading;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.loading = false,
    this.error,
  });

  bool get isStaff => user?.isStaff ?? false;
}

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _repo;
  StreamSubscription? _authSub;
  StreamSubscription? _userSub;

  AuthCubit(this._repo) : super(const AuthState()) {
    //listen for login and logout.
    _authSub = _repo.authChanges.listen((firebaseUser) {
      debugPrint('AUTH: login state changed, uid = ${firebaseUser?.uid}');
      _userSub?.cancel();

      if (firebaseUser == null) {
        emit(AuthState(status: AuthStatus.loggedOut, error: state.error));
        return;
      }

      debugPrint('AUTH: waiting for profile document...');
      _userSub = _repo.watchUser(firebaseUser.uid).listen(
            (user) {
          debugPrint('AUTH: profile arrived, name = ${user.name}, role = ${user.role}');
          emit(AuthState(status: AuthStatus.loggedIn, user: user));
        },
        onError: (e) {
          debugPrint('AUTH: profile FAILED: $e');
          emit(const AuthState(
            status: AuthStatus.loggedOut,
            error: 'Could not load your profile. Please sign in again.',
          ));
          _repo.signOut();
        },
      );
    });
  }

  Future<void> signIn(String email, String password) =>
      _attempt(() => _repo.signIn(email, password));

  Future<void> signUp(String name, String email, String password) =>
      _attempt(() => _repo.signUp(name, email, password));

  Future<void> signOut() => _repo.signOut();

  Future<void> _attempt(Future<void> Function() action) async {
    emit(AuthState(status: state.status, loading: true));
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      emit(AuthState(status: AuthStatus.loggedOut, error: _friendly(e.code)));
    } catch (e) {
      debugPrint('AUTH: action FAILED: $e');
      emit(const AuthState(
        status: AuthStatus.loggedOut,
        error: 'Something went wrong. Check your connection.',
      ));
      await _repo.signOut();
    }
  }

  //making my own error messages
  String _friendly(String code) => switch (code) {
    'invalid-credential' || 'wrong-password' || 'user-not-found' =>
    'Either your email or password is incorrect',
    'email-already-in-use' => 'email already exists',
    'weak-password' => 'Password must be at least 6 characters.',
    'invalid-email' => "email doesn't look right",
    'network-request-failed' => 'no internet connection',
    'too-many-requests' => 'Too many attempts. Wait',
    _ => 'Sign in failed ($code).',
  };

  @override
  Future<void> close() {
    _authSub?.cancel();
    _userSub?.cancel();
    return super.close();
  }
  Future<void> changeAvatar(File photo) async {
    final me = state.user;
    if (me == null) return;
    emit(AuthState(status: AuthStatus.loggedIn, user: me, loading: true));
    try {
      await _repo.updateAvatar(me.uid, photo);
    } catch (_) {
      emit(AuthState(
        status: AuthStatus.loggedIn,
        user: state.user,
        error: 'Error changing your photo, Try again.',
      ));
    }
  }
}