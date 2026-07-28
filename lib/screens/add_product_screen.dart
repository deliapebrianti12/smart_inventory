import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controller Utama
  final TextEditingController _kodeController = TextEditingController();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _lokasiController = TextEditingController();
  final TextEditingController _hargaController = TextEditingController();
  final TextEditingController _stokController = TextEditingController();

  // Controller untuk Varian Sementara
  final TextEditingController _warnaController = TextEditingController();
  final TextEditingController _ukuranController = TextEditingController();

  // State Kategori & List Varian yang Ditambahkan
  String _selectedCategory = "Atasan";
  final List<String> _categories = ["Atasan", "Bawahan", "Gamis", "Hijab", "Mukena"];
  final List<String> _varianList = [];

  @override
  void initState() {
    super.initState();
    _generateAutomaticCode();
  }

  // Fungsi membuat kode barang otomatis (Contoh: BRG011)
  void _generateAutomaticCode() async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('barang')
          .orderBy('kode_barang', descending: true)
          .limit(1)
          .get();

      if (!mounted) return;

      if (snapshot.docs.isNotEmpty) {
        String lastCode = snapshot.docs.first['kode_barang'];
        int lastNumber = int.parse(lastCode.replaceAll("BRG", ""));
        int newNumber = lastNumber + 1;
        _kodeController.text = "BRG${newNumber.toString().padLeft(3, '0')}";
      } else {
        _kodeController.text = "BRG001";
      }
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      _kodeController.text = "BRG001";
    }
  }

  // Fungsi menambah varian ke daftar bawah form
  void _addVarian() {
    String warna = _warnaController.text.trim().toUpperCase();
    String ukuran = _ukuranController.text.trim().toUpperCase();

    if (warna.isNotEmpty && ukuran.isNotEmpty) {
      setState(() {
        _varianList.add("$warna - $ukuran");
        _warnaController.clear();
        _ukuranController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Isi warna dan ukuran terlebih dahulu!")),
      );
    }
  }

  // Fungsi simpan data ke Firebase
  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseFirestore.instance.collection('barang').add({
          'kode_barang': _kodeController.text,
          'nama': _namaController.text.trim(),
          'kategori': _selectedCategory,
          'lokasi': _lokasiController.text.trim().isEmpty ? "-" : _lokasiController.text.trim(),
          'harga': int.tryParse(_hargaController.text) ?? 0,
          'stok': int.tryParse(_stokController.text) ?? 0,
          'varian': _varianList, 
          'created_at': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Produk berhasil disimpan ke Inventory!")),
        );
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menyimpan data: $e")),
        );
      }
    }
  }

  @override
  void dispose() {
    _kodeController.dispose();
    _namaController.dispose();
    _lokasiController.dispose();
    _hargaController.dispose();
    _stokController.dispose();
    _warnaController.dispose();
    _ukuranController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Tambah Busana Baru",
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Kode Barang (Read Only)
              TextFormField(
                controller: _kodeController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Kode Barang (Otomatis)",
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color(0xFFFBF7F5),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Nama Busana
              TextFormField(
                controller: _namaController,
                validator: (val) => val!.isEmpty ? "Nama busana tidak boleh kosong" : null,
                decoration: const InputDecoration(
                  labelText: "Nama Busana",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Dropdown Kategori
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: "Pilih Kategori",
                  border: OutlineInputBorder(),
                ),
                items: _categories.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // 4. Lokasi Penempatan
              TextFormField(
                controller: _lokasiController,
                decoration: const InputDecoration(
                  labelText: "Lokasi Penempatan (Misal: Rak A01)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // 5. Baris Harga & Stok Awal
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _hargaController,
                      keyboardType: TextInputType.number,
                      validator: (val) => val!.isEmpty ? "Isi harga" : null,
                      decoration: const InputDecoration(
                        labelText: "Harga (Rp)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stokController,
                      keyboardType: TextInputType.number,
                      validator: (val) => val!.isEmpty ? "Isi stok awal" : null,
                      decoration: const InputDecoration(
                        labelText: "Stok Awal",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 6. FORM INPUTAN VARIAN
              const Text(
                "Varian (Warna & Ukuran):",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.brown),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _warnaController,
                      decoration: const InputDecoration(
                        labelText: "Warna",
                        border: OutlineInputBorder(),
                        hintText: "Misal: Hitam",
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _ukuranController,
                      decoration: const InputDecoration(
                        labelText: "Ukuran",
                        border: OutlineInputBorder(),
                        hintText: "Misal: XL",
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Tombol Tambah (+) Varian
                  GestureDetector(
                    onTap: _addVarian,
                    child: Container(
                      height: 54,
                      width: 54,
                      decoration: BoxDecoration(
                        color: Colors.brown[600],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),

              // Tempat menampilkan Varian yang telah ditambahkan
              if (_varianList.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: _varianList.map((varian) {
                    return Chip(
                      label: Text(varian, style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.brown[50],
                      deleteIcon: const Icon(Icons.cancel, size: 16, color: Colors.red),
                      onDeleted: () {
                        setState(() {
                          _varianList.remove(varian);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 32),

              // 7. Tombol Simpan Utama
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _saveProduct,
                  child: const Text(
                    "SIMPAN KE INVENTORY",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}