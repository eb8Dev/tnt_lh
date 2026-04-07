import 'package:google_sign_in/google_sign_in.dart';

void main() async {
  // Check v7 API
  final GoogleSignIn signIn = GoogleSignIn.instance;

  // Check initialize
  await signIn.initialize(
    serverClientId:
        '138992055382-mqqiupgfm3qv1ihoi4e1oq2r6k65f12o.apps.googleusercontent.com',
  );

  // Check authenticate
  final GoogleSignInAccount user = await signIn.authenticate();

  // Check authentication property (not a future)
  final GoogleSignInAuthentication auth = user.authentication;

  // Check tokens (idToken is typically what's used)
  print(auth.idToken);
}
