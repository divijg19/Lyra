import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/lyra_endpoints.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLaunching = false;
  String? _error;

  Future<void> _launchSpotifyLogin() async {
    setState(() {
      _isLaunching = true;
      _error = null;
    });

    final loginUri = ref.read(spotifyLoginUriProvider);
    final launched = await launchUrl(
      loginUri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      setState(() {
        _error = 'Unable to open Spotify login.';
      });
    }

    if (mounted) {
      setState(() {
        _isLaunching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lyra Login')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Connect Spotify to start building your Lyra identity.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isLaunching ? null : _launchSpotifyLogin,
                child: Text(
                  _isLaunching ? 'Opening...' : 'Continue with Spotify',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
