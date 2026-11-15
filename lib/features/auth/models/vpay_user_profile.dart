class VPayUserProfile {
  const VPayUserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.businessName,
    this.phone,
    this.businessCategory,
    this.businessAddress,
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final String status;
  final String? businessName;
  final String? phone;
  final String? businessCategory;
  final String? businessAddress;

  factory VPayUserProfile.fromJson(Map<String, dynamic> json) {
    return VPayUserProfile(
      uid: json['uid'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
      businessName: json['businessName'] as String?,
      phone: json['phone'] as String?,
      businessCategory: json['businessCategory'] as String?,
      businessAddress: json['businessAddress'] as String?,
    );
  }
}
