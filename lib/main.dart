import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_codebootcamp/View/LoginView.dart';
import 'package:flutter_application_codebootcamp/View/RegisterView.dart';

import 'firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    title: 'FireBase Fluttter Demo',
    theme: ThemeData(
      primarySwatch: Colors.blue,
    ),
    home: const HomePage(),
    routes: {
      '/Login/': (context) => const LoginView(),
      '/Register/': (context) => const RegisterView()
    },
  ));
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ),
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.done:
              final user = FirebaseAuth.instance.currentUser;
              // print(user?.emailVerified);
              // if (user?.emailVerified ?? false) {
              //   return const Text('Done');
              // } else {
              //   return const VerifyEmailView();
              // }
              return const LoginView();
            default:
              return const CircularProgressIndicator();
          }
        });
  }
}
