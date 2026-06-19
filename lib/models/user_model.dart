class UserModel {
  final String username;
  final String role; // Contoh: 'Admin' atau 'Staf'

  UserModel({
    required this.username, 
    required this.role,
  });

  // Tambahan fitur baru (Tanpa mengubah variable yang sudah ada):
  
  // 1. Fungsi untuk mengubah ke bentuk Map (Dipakai saat simpan data)
  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'role': role,
    };
  }

  // 2. Fungsi untuk membaca dari bentuk Map (Dipakai saat ambil data)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      username: map['username'] ?? '',
      role: map['role'] ?? 'Staf',
    );
  }
}