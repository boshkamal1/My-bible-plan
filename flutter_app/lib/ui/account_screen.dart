import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../services/cloud.dart';
import '../state/app_state.dart';
import 'theme.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _createAccount = false;
  bool _busy = false;
  String? _error;

  String _t(String ar, String en) => gEn ? en : ar;

  @override
  void initState() {
    super.initState();
    context.read<Cloud>().init(context.read<AppState>());
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(Cloud cloud, AppState state) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await cloud.signInEmail(
      _email.text,
      _password.text,
      create: _createAccount,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    await cloud.sync(state);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _googleSignIn(Cloud cloud, AppState state) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await cloud.signInGoogle();
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error == 'cancelled' ? null : error;
      });
      return;
    }
    await cloud.sync(state);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<Cloud>();
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('account'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.account_circle_outlined, size: 58, color: kGold),
              const SizedBox(height: 12),
              Text(
                _t('حسابك ورحلتك في مكان واحد',
                    'Your account, all in one place'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  'سجّل الدخول لمزامنة تقدمك وملاحظاتك بين أجهزتك.',
                  'Sign in to sync your reading progress and notes across devices.',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (!cloud.available)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _t(
                        'تسجيل الدخول غير متاح حاليًا. حاول مرة أخرى بعد قليل.',
                        'Sign-in is temporarily unavailable. Please try again later.',
                      ),
                    ),
                  ),
                )
              else if (cloud.signedIn)
                _signedInCard(cloud, state)
              else
                _signInForm(cloud, state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _signedInCard(Cloud cloud, AppState state) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.verified_user_outlined, color: kGold),
                title:
                    Text(cloud.user?.displayName ?? cloud.user?.email ?? '—'),
                subtitle: Text(
                  cloud.lastSync == null
                      ? _t('تم تسجيل الدخول', 'Signed in')
                      : tr('synced'),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed:
                    cloud.busy ? null : () => cloud.sync(state, force: true),
                icon: const Icon(Icons.sync),
                label: Text(tr('syncNow')),
              ),
              TextButton(
                onPressed: cloud.signOut,
                child: Text(tr('signOut')),
              ),
            ],
          ),
        ),
      );

  Widget _signInForm(Cloud cloud, AppState state) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : () => _googleSignIn(cloud, state),
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: Text(tr('signInGoogle')),
                ),
                const SizedBox(height: 8),
                Text(
                  _t('أو استخدم بريدك الإلكتروني', 'or use your email'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: tr('email'),
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || !value.contains('@')
                      ? _t('اكتب بريدًا إلكترونيًا صحيحًا',
                          'Enter a valid email')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(cloud, state),
                  decoration: InputDecoration(
                    labelText: tr('password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.length < 6
                      ? _t('كلمة المرور 6 أحرف على الأقل',
                          'Use at least 6 characters')
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _submit(cloud, state),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(_createAccount ? tr('register') : tr('signIn')),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _createAccount = !_createAccount;
                            _error = null;
                          }),
                  child: Text(
                    _createAccount
                        ? _t('عندك حساب؟ سجّل الدخول',
                            'Already have an account? Sign in')
                        : _t('مستخدم جديد؟ أنشئ حسابًا',
                            'New here? Create an account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
