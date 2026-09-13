import '../entities/user_profile.dart';

abstract class AuthRepository {
  Future<UserProfile?> getCurrentUserProfile();
  Stream<UserProfile?> get authStateChanges;
  Future<UserProfile> signInWithEmailPassword({
    required String email,
    required String password,
  });
  Future<UserProfile> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
  });
  Future<void> signOut();
}
