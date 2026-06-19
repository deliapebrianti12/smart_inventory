import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:intl/intl.dart';

// Import untuk penanganan download di lintas platform (Web Browser & Desktop)
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html; 
import 'dart:io' show File;
import 'package:path_provider/path_provider.dart';

import '../models/user_model.dart'; // Menghubungkan hak akses user
import 'add_product_screen.dart'; 

class ListProductScreen extends StatefulWidget {
  final UserModel user; // Menerima data user dari Dashboard

  const ListProductScreen({super.key, required this.user});

  @override
  State<ListProductScreen> createState() => _ListProductScreenState();
}

class _ListProductScreenState extends State<ListProductScreen> {
  final ScreenshotController screenshotController = ScreenshotController();
  
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // --- VARIABLE KATEGORI ---
  String selectedCategory = "Semua";
  final List<String> categories = ["Semua", "Atasan", "Bawahan", "Gamis", "Hijab", "Mukena"];

  // --- FUNGSI DOWNLOAD QR LINTAS PLATFORM (WEB & DESKTOP/MOBILE) ---
  Future<void> _downloadQRCode(String kodeBarang, Uint8List qrBytes) async {
    try {
      final String namaFile = "QR_$kodeBarang.png";

      if (kIsWeb) {
        // Alur download otomatis jika dijalankan di Google Chrome / Browser
        final blob = html.Blob([qrBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", namaFile)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        // Alur download jika dijalankan sebagai aplikasi desktop / mobile native
        final direktori = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        final String pathLengkap = "${direktori.path}/$namaFile";
        final File fileLokal = File(pathLengkap);
        await fileLokal.writeAsBytes(qrBytes);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("QR Code $kodeBarang berhasil diunduh!"),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengunduh QR: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cek status admin langsung menggunakan property .role dari model asli kamu
    final bool isAdmin = widget.user.role == 'Admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Daftar Stok Alsakina",
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120), 
          child: Column(
            children: [
              // 1. Kolom Pencarian
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Cari nama atau kode barang...",
                    prefixIcon: const Icon(Icons.search, color: Colors.brown),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              // 2. Barisan Kategori (Chips)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: categories.map((cat) {
                    bool isSelected = selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            selectedCategory = cat;
                          });
                        },
                        selectedColor: Colors.brown[100],
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.brown[900] : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        backgroundColor: Colors.brown[600],
                        checkmarkColor: Colors.brown[900],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('barang')
            .orderBy('created_at', descending: true) 
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Terjadi kesalahan"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            var nama = (data['nama'] ?? '').toString().toLowerCase();
            var kode = (data['kode_barang'] ?? '').toString().toLowerCase();
            var kategoriBarang = (data['kategori'] ?? 'Semua').toString();

            bool matchesSearch = nama.contains(searchQuery) || kode.contains(searchQuery);
            bool matchesCategory = selectedCategory == "Semua" || kategoriBarang == selectedCategory;

            return matchesSearch && matchesCategory;
          }).toList();

          if (docs.isEmpty) {
            return const Center(child: Text("Barang tidak ditemukan."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var doc = docs[index];
              var data = doc.data() as Map<String, dynamic>;
              
              num hargaBarang = num.tryParse(data['harga'].toString()) ?? 0;
              int stokSekarang = int.tryParse(data['stok'].toString()) ?? 0;
              String lokasi = data['lokasi'] ?? '-';
              List varian = (data['varian'] is List) ? data['varian'] : [];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.brown[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.archive, color: Colors.brown),
                  ),
                  title: Text(
                    data['nama'] ?? '-', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("ID: ${data['kode_barang']} | Lokasi: $lokasi", 
                        style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                      Text("Stok: $stokSekarang | ${data['kategori'] ?? 'Tanpa Kategori'}",
                        style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.w500, fontSize: 12)),
                      if (varian.isNotEmpty)
                        Text("Varian: ${varian.join(', ')}", 
                          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                    ],
                  ),
                  trailing: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(hargaBarang),
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 15),
                        GestureDetector(
                          onTap: () => _showQRCodeDialog(context, data),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.brown[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.qr_code_2, size: 24, color: Colors.brown),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // PEMBATASAN AKSES TEKAN LAMA: Diubah ke data role asli milikmu
                  onLongPress: () {
                    if (isAdmin) {
                      _showEditDeleteOptions(context, doc.id, data);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Akses Ditolak: Hanya Admin yang diperbolehkan mengubah atau menghapus data barang!"),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      
      // PEMBATASAN AKSES FAB (+): Menggunakan status isAdmin berbasis role milikmu
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              backgroundColor: Colors.brown[700],
              foregroundColor: Colors.white,
              tooltip: "Tambah Busana Baru",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddProductScreen(), 
                  ),
                );
              },
              child: const Icon(Icons.add, size: 28),
            )
          : null,
    );
  }

  // --- FUNGSI HELPER (EDIT, DELETE, QR) ---
  void _showEditDeleteOptions(BuildContext context, String docId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Opsi Barang: ${data['nama']}", style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text("Edit Nama, Harga & Kategori"),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(context, docId, data);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Hapus Barang"),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, docId, data['nama']);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, String docId, Map<String, dynamic> data) {
    final TextEditingController nameController = TextEditingController(text: data['nama']);
    final TextEditingController priceController = TextEditingController(text: data['harga'].toString());
    final TextEditingController locationController = TextEditingController(text: data['lokasi'] ?? '');

    String? currentCat = data['kategori'];
    if (!categories.contains(currentCat) || currentCat == "Semua") currentCat = "Atasan";

    showDialog(
      context: context,
      builder: (context) {
        String tempCat = currentCat!;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Barang"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: "Nama Barang")),
                    TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Harga")),
                    TextField(controller: locationController, decoration: const InputDecoration(labelText: "Lokasi (Rak)")),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: tempCat,
                      decoration: const InputDecoration(labelText: "Kategori", border: OutlineInputBorder()),
                      items: categories.where((c) => c != "Semua").map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (newValue) => setDialogState(() => tempCat = newValue!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("BATAL")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[700]),
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('barang').doc(docId).update({
                      'nama': nameController.text,
                      'harga': priceController.text,
                      'kategori': tempCat,
                      'lokasi': locationController.text,
                    });
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data diperbarui!")));
                    }
                  },
                  child: const Text("SIMPAN", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String docId, String nama) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Barang?"),
        content: Text("Apakah Anda yakin ingin menghapus '$nama'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("BATAL")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('barang').doc(docId).delete();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Barang telah dihapus")));
              }
            },
            child: const Text("HAPUS", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showQRCodeDialog(BuildContext context, Map<String, dynamic> data) {
    List varian = (data['varian'] is List) ? data['varian'] : [];
    
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white, 
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Text(data['nama'] ?? 'Detail Barang', textAlign: TextAlign.center, style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
            const Divider(),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: SingleChildScrollView( 
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _infoRow("Lokasi", data['lokasi'] ?? "-"),
                _infoRow("Kategori", data['kategori'] ?? "-"),
                if (varian.isNotEmpty) _infoRow("Varian", varian.join(", ")),
                const SizedBox(height: 15),
                Screenshot(
                  controller: screenshotController,
                  child: Container(
                    color: Colors.white, 
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Alsakina Boutique", style: GoogleFonts.playfairDisplay(fontSize: 12, color: Colors.brown)),
                        const SizedBox(height: 10),
                        QrImageView(data: data['kode_barang'] ?? '', version: QrVersions.auto, size: 160.0, gapless: false),
                        const SizedBox(height: 10),
                        Text(data['kode_barang'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  onPressed: () async {
                    final Uint8List? image = await screenshotController.capture();
                    if (image != null) {
                      await _downloadQRCode(data['kode_barang'] ?? 'BARANG', image);
                    }
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text("DOWNLOAD QR"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[700], foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("TUTUP", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 65, child: Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}