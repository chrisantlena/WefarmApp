class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? photoUrl;
  final String? address;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.photoUrl,
    this.address,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    String? photoUrl =
        json['photoUrl'] ?? json['photo_url'] ?? json['profile_image'];

    print('User.fromJson - Raw JSON: $json');
    print('User.fromJson - Extracted photoUrl: $photoUrl');

    return User(
      id: json['id'].toString(),
      name: json['name'] ?? json['username'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      photoUrl: photoUrl,
      address: json['address'],
    );
  }

  // Method untuk convert User ke JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'photo_url': photoUrl, // Untuk kompatibilitas dengan database
      'profile_image': photoUrl, // Untuk kompatibilitas tambahan
      'address': address,
    };
  }

  // CopyWith method untuk membuat copy User dengan beberapa field yang diubah
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    String? address,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      address: address ?? this.address,
    );
  }

  @override
  String toString() {
    return 'User{id: $id, name: $name, email: $email, phone: $phone, photoUrl: $photoUrl, address: $address}';
  }
}
