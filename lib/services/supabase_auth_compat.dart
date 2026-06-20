import 'dart:async';

import 'supabase_auth_service.dart';

class AppAuthException implements Exception {
  const AppAuthException({this.code = 'supabase-error', this.message});

  final String code;
  final String? message;

  @override
  String toString() => message ?? code;
}

enum Persistence { none }

class User extends SupabaseAuthUser {
  User(SupabaseAuthUser delegate)
    : super(id: delegate.id, email: delegate.email, name: delegate.name);

  Future<void> updateDisplayName(String name) {
    return supabaseAuth.updateDisplayName(name);
  }

  Future<void> updatePassword(String password) {
    return supabaseAuth.updatePassword(password).catchError((error) {
      if (error is SupabaseAuthException) {
        throw AppAuthException(
          code: 'supabase-auth',
          message: error.message,
        );
      }

      throw error;
    });
  }
}

class UserCredential {
  const UserCredential(this.user);

  final User? user;
}

class AppAuth {
  AppAuth._({this.keepCurrentSession = false});

  final bool keepCurrentSession;

  static final AppAuth instance = AppAuth._();

  static AppAuth instanceFor({Object? app}) {
    return AppAuth._(keepCurrentSession: true);
  }

  User? get currentUser {
    final user = supabaseAuth.currentUser;
    return user == null ? null : User(user);
  }

  Stream<User?> authStateChanges() {
    return supabaseAuth.authStateChanges().map(
      (user) => user == null ? null : User(user),
    );
  }

  Future<void> setPersistence(Persistence persistence) async {}

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final session = await supabaseAuth.signInWithPassword(
        email: email,
        password: password,
      );
      return UserCredential(User(session.user));
    } on SupabaseAuthException catch (error) {
      throw AppAuthException(
        code: 'supabase-auth',
        message: error.message,
      );
    }
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final user = await supabaseAuth.signUp(
        email: email,
        password: password,
        keepCurrentSession: keepCurrentSession,
      );
      return UserCredential(User(user));
    } on SupabaseAuthException catch (error) {
      throw AppAuthException(
        code: 'supabase-auth',
        message: error.message,
      );
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return supabaseAuth.sendPasswordResetEmail(email);
  }

  Future<void> signOut() {
    return supabaseAuth.signOut();
  }
}
