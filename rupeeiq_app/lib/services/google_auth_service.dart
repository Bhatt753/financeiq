import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  static final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Launches the Google sign-in flow.
  /// Returns {google_id, email, name, avatar} or null if cancelled / error.
  static Future<Map<String, String>?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;
      return {
        'google_id': account.id,
        'email'    : account.email,
        'name'     : account.displayName ?? '',
        'avatar'   : account.photoUrl    ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }
}
