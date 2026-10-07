class VPayUserProfile {
  const VPayUserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final String status;

  factory VPayUserProfile.fromJson(Map<String, dynamic> json) {
    return VPayUserProfile(
      uid: json['uid'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
    );
  }
}
