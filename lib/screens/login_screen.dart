import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart'; // Menghubungkan ke UserModel kamu
import 'dashboard_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  
  // TAMBAHAN: State untuk mengatur sembunyikan/lihat password
  bool _obscurePassword = true;

  // Fungsi Login Firebase + Ambil Role
  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // 1. Proses Autentikasi ke Firebase Auth
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // 2. Ambil Data User & Role dari Cloud Firestore
        String uid = userCredential.user!.uid;
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        UserModel loggedInUser;

        if (userDoc.exists) {
          // Jika data user terdaftar di firestore, gunakan datanya
          Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
          loggedInUser = UserModel.fromMap(data);
        } else {
          // Fallback aman jika data di firestore belum dibuat (default username diambil dari email)
          String email = _emailController.text.trim();
          String defaultUsername = email.split('@')[0];
          loggedInUser = UserModel(
            username: defaultUsername,
            role: email.contains('admin') ? 'Admin' : 'Staf',
          );
        }

        if (mounted) {
          // 3. Pindah ke Dashboard dengan membawa data UserModel terbaru
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(user: loggedInUser),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        String message = "Terjadi kesalahan login";
        if (e.code == 'user-not-found') {
          message = "Email tidak terdaftar.";
        } else if (e.code == 'wrong-password') {
          message = "Password salah.";
        } else if (e.code == 'invalid-email') {
          message = "Format email salah.";
        } else if (e.code == 'user-disabled') {
          message = "Akun ini telah dinonaktifkan.";
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memuat data hak akses: $e"), backgroundColor: Colors.orange),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    // TAMBAHAN: Membersihkan controller dari memori ketika screen ditutup
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Judul Butik
                Text(
                  "ALSAKINA",
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: Colors.brown[800],
                  ),
                ),
                Text(
                  "Smart Inventory System",
                  style: GoogleFonts.lato(
                    fontSize: 16,
                    color: Colors.brown[400],
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 60),

                // Field Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next, // Menghubungkan fokus ke input berikutnya
                  decoration: InputDecoration(
                    labelText: "Email Staf",
                    hintText: "admin@alsakina.com",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Masukkan email terdaftar";
                    }
                    if (!value.contains('@')) {
                      return "Format email tidak valid";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Field Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword, // Menggunakan state dinamis
                  textInputAction: TextInputAction.done, // Menandakan pengisian selesai
                  onFieldSubmitted: (_) => _handleLogin(), // Menjalankan fungsi login jika klik enter/done di keyboard
                  decoration: InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                    // TAMBAHAN: Tombol Mata untuk Sembunyikan/Tampilkan sandi secara interaktif
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) =>
                      value!.length < 6 ? "Minimal 6 karakter" : null,
                ),
                const SizedBox(height: 30),

                // Tombol Login / Loading Indicator
                _isLoading
                    ? const CircularProgressIndicator(color: Colors.brown)
                    : SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            "MASUK KE SISTEM",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 40),
                
                // Footer
                Text(
                  "Smart Inventory v1.0",
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}