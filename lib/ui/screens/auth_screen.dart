import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// import '../../app.dart';
import '../../logic/auth_cubit.dart';

//only alu emails are allowed
const campusDomains = ['alustudent.com', 'alueducation.com'];

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _entryForm = GlobalKey<FormState>();
  final _nameInput = TextEditingController();
  final _emailInput = TextEditingController();
  final _secretInput = TextEditingController();
  bool _isJoining = false; //false means signing in true means  creating an account
  bool _hideSecret = true;

  @override
  void dispose() {
    _nameInput.dispose();
    _emailInput.dispose();
    _secretInput.dispose();
    super.dispose();
  }

  void _proceed() {
    if (!_entryForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final gate = context.read<AuthCubit>();
    if (_isJoining) {
      gate.signUp(_nameInput.text, _emailInput.text, _secretInput.text);
    } else {
      gate.signIn(_emailInput.text, _secretInput.text);
    }
  }

  String? _checkEmail(String? value) {
    final email = (value ?? '').trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Please enterr a valid email';
    }
    final isCampus = campusDomains.any((d) => email.endsWith('@$d'));
    if (_isJoining && campusDomains.isNotEmpty && !isCampus) {
      return 'Use your ALU email';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final words = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _entryForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset('assets/images/ALU.jpeg', height: 80),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _isJoining ? 'Join ALU Reporting' : 'Welcome back',
                    textAlign: TextAlign.center,
                    style: words.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isJoining
                        ? 'Create an account'
                        : 'Sign in',
                    textAlign: TextAlign.center,
                    style: words.bodyMedium?.copyWith(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 32),

                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: _isJoining
                        ? Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
                        controller: _nameInput,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v ?? '').trim().length < 2
                            ? 'Enter your name'
                            : null,
                      ),
                    )
                        : const SizedBox.shrink(),
                  ),

                  TextFormField(
                    controller: _emailInput,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: _checkEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _secretInput,
                    obscureText: _hideSecret,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_hideSecret
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _hideSecret = !_hideSecret),
                      ),
                    ),
                    validator: (v) =>
                    (v ?? '').length < 6 ? 'At least 6 characters' : null,
                    onFieldSubmitted: (_) => _proceed(),
                  ),
                  const SizedBox(height: 24),

                  //only this part listens to the cubit
                  BlocBuilder<AuthCubit, AuthState>(
                    builder: (context, auth) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (auth.error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              auth.error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          ),
                        FilledButton(
                          onPressed: auth.loading ? null : _proceed,
                          child: auth.loading
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : Text(_isJoining ? 'Create account' : 'SignIn'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _isJoining = !_isJoining),
                    child: Text(_isJoining
                        ? 'Already have an account? SignIn'
                        : 'New here? Create account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}