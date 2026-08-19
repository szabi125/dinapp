import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLoading = false;

  static const String webClientId =
      '361116656518-clshbo5sgoquh1ijddgo89f5kutoc9dq.apps.googleusercontent.com';

  Future<void> signIn() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      // =========================================================
      // WEB
      // =========================================================

      if (kIsWeb) {
        final GoogleAuthProvider googleProvider =
        GoogleAuthProvider();

        googleProvider.addScope(
          'email',
        );

        googleProvider.addScope(
          'profile',
        );

        await FirebaseAuth.instance.signInWithPopup(
          googleProvider,
        );
      }

      // =========================================================
      // ANDROID / iPHONE
      // =========================================================

      else {
        final GoogleSignIn googleSignIn =
            GoogleSignIn.instance;

        await googleSignIn.initialize(
          clientId: webClientId,
        );

        final GoogleSignInAccount googleUser =
        await googleSignIn.authenticate();

        final GoogleSignInAuthentication googleAuth =
            googleUser.authentication;

        final AuthCredential credential =
        GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Firebase bejelentkezési hiba: ${e.message ?? e.code}",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Bejelentkezési hiba: $e",
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101E2E),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 450,
            ),

            child: Padding(
              padding: const EdgeInsets.all(24),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  const Text(
                    "DINA'95",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    "JELENLÉTI RENDSZER",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 50),

                  const Text(
                    "Bejelentkezés",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 52,

                    child: ElevatedButton(
                      onPressed: isLoading ? null : signIn,

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor:
                        const Color(0xFF101E2E),

                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(10),
                        ),
                      ),

                      child: isLoading
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                        CircularProgressIndicator(),
                      )
                          : const Row(
                        mainAxisAlignment:
                        MainAxisAlignment.center,

                        children: [
                          Icon(Icons.login),

                          SizedBox(width: 10),

                          Text(
                            "Bejelentkezés Google-fiókkal",
                            style: TextStyle(
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
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