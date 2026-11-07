import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/repositories.dart';
import 'logic/auth_cubit.dart';
import 'logic/incident_cubit.dart';
import 'ui/screens/auth_screen.dart';
import 'ui/screens/home_screen.dart';

const primary = Color(0xFF0B1F44);
const accent = Color(0xFFD7262E);

class AluReportingApp extends StatelessWidget {
  const AluReportingApp({super.key});

  @override
  Widget build(BuildContext context) {
    //AuthCubit is on top of everything, so every screen checks authentication status"
    return BlocProvider(
      create: (_) => AuthCubit(AuthRepository()),
      child: MaterialApp(
        title: 'ALU Reporting',
        debugShowCheckedModeBanner: false,
        theme: _aluTheme(),
        home: const _Doorman(),
      ),
    );
  }
}

//doorman decides the screen you see depending on login status
class _Doorman extends StatelessWidget {
  const _Doorman();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (before, after) => before.status != after.status,
      builder: (context, auth) => switch (auth.status) {
        AuthStatus.unknown => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        AuthStatus.loggedOut => const AuthScreen(),
        AuthStatus.loggedIn => BlocProvider(
          create: (_) => IncidentCubit(IncidentRepository()),
          child: const HomeScreen(),
        ),
      },
    );
  }
}

void openWithReports(BuildContext context, Widget page) {
  final reports = context.read<IncidentCubit>();
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => BlocProvider.value(value: reports, child: page),
  ));
}

ThemeData _aluTheme() {
  final rounded12 = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade300),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
    ),
    scaffoldBackgroundColor: const Color(0xFFF4F5F7),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: primary.withValues(alpha: 0.1),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: rounded12,
      enabledBorder: rounded12,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}