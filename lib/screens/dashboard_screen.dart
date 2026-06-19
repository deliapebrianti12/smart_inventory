import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import '../models/user_model.dart'; 
import 'list_product_screen.dart'; 
import 'add_product_screen.dart';  
import 'scanner_screen.dart';      
import 'history_screen.dart';      
import 'report_screen.dart';       
import 'login_screen.dart';        

class DashboardScreen extends StatelessWidget {
  final UserModel user;

  const DashboardScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // Memakai getter pintar dari model data terupdate
    final bool isAdmin = user.role == 'Admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Alsakina Smart Inventory",
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut(); // Menambahkan fungsi sign out agar sesi bersih
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Selamat Datang, ${user.username}",
              style: GoogleFonts.lato(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.brown[800],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "Hak Akses: ${user.role}",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 25),
            
            // Grid Menu Utama
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  _buildMenuCard(
                    context, 
                    "Barang Masuk", 
                    Icons.qr_code_scanner, 
                    Colors.blue,
                    () {
                      // PERBAIKAN: Menghapus 'const' dan mengoper parameter objek data 'user'
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScannerScreen(scanMode: "Tambah", user: user),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context, 
                    "Barang Keluar", 
                    Icons.qr_code_scanner, 
                    Colors.red,
                    () {
                      // PERBAIKAN: Menghapus 'const' dan mengoper parameter objek data 'user'
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScannerScreen(scanMode: "Jual", user: user),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context, 
                    "Data Barang", 
                    Icons.inventory_2, 
                    Colors.orange,
                    () {
                      // Mengoper objek user aktif ke ListProductScreen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ListProductScreen(user: user),
                        ),
                      );
                    },
                  ),
                  _buildMenuCard(
                    context, 
                    "Riwayat Stok", 
                    Icons.history, 
                    Colors.green,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const HistoryScreen()),
                      );
                    },
                  ),
                  if (isAdmin)
                    _buildMenuCard(
                      context, 
                      "Laporan", 
                      Icons.bar_chart, 
                      Colors.purple,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ReportScreen()),
                        );
                      },
                    ),
                  if (isAdmin)
                    _buildMenuCard(
                      context, 
                      "Tambah Staf", 
                      Icons.person_add, 
                      Colors.teal,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddStaffScreen()),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, 
    String title, 
    IconData icon, 
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title, 
              textAlign: TextAlign.center, 
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddStaffScreen extends StatefulWidget {
  const AddStaffScreen({super.key});

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController(); 
  final _passwordController = TextEditingController(); 
  bool _isLoading = false;

  Future<void> _registerStaff() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });
      try {
        UserCredential credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
          'username': _usernameController.text.trim(),
          'role': 'Staf',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Staf "${_usernameController.text}" Berhasil Terdaftar!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); 
        }
      } on FirebaseAuthException catch (e) {
        String errMsg = "Gagal mendaftarkan staf";
        if (e.code == 'weak-password') {
          errMsg = "Password terlalu lemah (minimal 6 karakter).";
        } else if (e.code == 'email-already-in-use') {
          errMsg = "Email tersebut sudah digunakan akun lain.";
        } else if (e.code == 'invalid-email') {
          errMsg = "Format penulisan email salah.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Terjadi kesalahan teknis: $e"), backgroundColor: Colors.orange),
        );
      } finally {
        if (mounted) setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Staf Baru'),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Buat Akun Staf',
                  style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown[800]),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap Staf',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Nama tidak boleh kosong' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Staf',
                    hintText: 'contoh@alsakina.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Email tidak boleh kosong' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password Akun Staf',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) => value == null || value.length < 6 ? 'Password minimal 6 karakter' : null,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _isLoading ? null : _registerStaff,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown[700],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('DAFTARKAN SEBAGAI STAF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}