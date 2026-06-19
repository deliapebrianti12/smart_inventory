import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart'; // IMPORT MODEL USER

class ScannerScreen extends StatefulWidget {
  final String scanMode; // "Tambah" untuk Barang Masuk, "Jual" untuk Barang Keluar
  final UserModel user;  // Menerima objek data user yang sedang aktif

  const ScannerScreen({super.key, required this.scanMode, required this.user});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool isScanCompleted = false;
  final TextEditingController _qtyController = TextEditingController();
  late String _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.scanMode; // Menyesuaikan mode dari halaman dashboard
  }

  // Fungsi pencarian data, dipanggil oleh Scanner maupun Pilihan Manual List
  void _processScannedData(String code) async {
    if (isScanCompleted) return;
    setState(() => isScanCompleted = true);

    try {
      var result = await FirebaseFirestore.instance
          .collection('barang')
          .where('kode_barang', isEqualTo: code)
          .get();

      if (result.docs.isNotEmpty) {
        var doc = result.docs.first;
        var data = doc.data();
        _showResultModal(doc.id, data);
      } else {
        _showErrorDialog(message: "Barang dengan kode $code tidak ditemukan!");
      }
    } catch (e) {
      _showErrorDialog(message: "Terjadi kesalahan: $e");
    }
  }

  // Dialog Pop-up untuk Memilih Barang Secara Otomatis dari List Firestore
  void _showManualInputDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.inventory, color: Colors.brown),
              SizedBox(width: 10),
              Text("Pilih Barang Manual"),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 350, // Batas tinggi kotak pop-up list barang
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('barang').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Gagal mengambil data"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(child: Text("Tidak ada data barang di database"));
                }

                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    var itemData = docs[index].data() as Map<String, dynamic>;
                    String namaBarang = itemData['nama'] ?? itemData['nama_barang'] ?? 'Tanpa Nama';
                    String kodeBarang = itemData['kode_barang'] ?? '-';
                    int stok = int.tryParse(itemData['stok'].toString()) ?? 0;

                    return ListTile(
                      title: Text(namaBarang, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Kode: $kodeBarang | Stok: $stok"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.brown),
                      onTap: () {
                        Navigator.pop(context); // Tutup dialog list barang
                        
                        if (kodeBarang != '-') {
                          _processScannedData(kodeBarang);
                        } else {
                          _showSnackbar("Kode barang tidak valid!", Colors.red);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("BATAL", style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );
  }

  void _showResultModal(String docId, Map<String, dynamic> data) {
    String nama = data['nama'] ?? data['nama_barang'] ?? 'Tanpa Nama';
    int stokTersedia = int.tryParse(data['stok'].toString()) ?? 0;
    String kode = data['kode_barang'] ?? '-';
    
    _qtyController.text = "1";
    _selectedMode = widget.scanMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Text(nama, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text("Kode: $kode", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            
            // Indikator Status Transaksi Aktif
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedMode == "Jual" ? Colors.red[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedMode == "Jual" ? Colors.red.shade200 : Colors.green.shade200,
                ),
              ),
              child: Text(
                _selectedMode == "Jual" ? "MODE: BARANG KELUAR" : "MODE: BARANG MASUK",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _selectedMode == "Jual" ? Colors.red[700] : Colors.green[700],
                ),
              ),
            ),
            const Divider(height: 30),
            
            Text("Stok Saat Ini: $stokTersedia", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 15),
            
            // Input Qty
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    int val = int.tryParse(_qtyController.text) ?? 1;
                    if (val > 1) _qtyController.text = (val - 1).toString();
                  },
                  icon: const Icon(Icons.remove_circle_outline, size: 30),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _qtyController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    int val = int.tryParse(_qtyController.text) ?? 1;
                    _qtyController.text = (val + 1).toString();
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 30, color: Colors.blue),
                ),
              ],
            ),
            
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("BATAL"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      int qty = int.tryParse(_qtyController.text) ?? 0;
                      if (qty <= 0) {
                        _showSnackbar("Jumlah tidak valid", Colors.orange);
                        return;
                      }
                      
                      if (_selectedMode == "Jual" && qty > stokTersedia) {
                        _showSnackbar("Stok tidak mencukupi!", Colors.red);
                      } else {
                        _updateDataStok(docId, nama, kode, qty, _selectedMode);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedMode == "Jual" ? Colors.red[700] : Colors.green[700],
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_selectedMode == "Jual" ? "KONFIRMASI KELUAR" : "KONFIRMASI MASUK"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => isScanCompleted = false);
    });
  }

  // PERBAIKAN LOGIKA: Ditambahkan pasangan titik dua (: qty) pada operator ternary agar tidak error
  Future<void> _updateDataStok(String docId, String nama, String kode, int qty, String mode) async {
    Navigator.pop(context);

    try {
      int valueChange = (mode == "Jual") ? -qty : qty;
      String tipeRiwayat = (mode == "Jual") ? 'Scan Keluar' : 'Restock Masuk';

      await FirebaseFirestore.instance.collection('barang').doc(docId).update({
        'stok': FieldValue.increment(valueChange),
      });

      // Menyimpan data riwayat berdasarkan nama lengkap staff yang login secara dinamis
      await FirebaseFirestore.instance.collection('riwayat').add({
        'id_barang': docId,
        'kode_barang': kode,
        'nama_barang': nama,
        'jumlah': qty,
        'tipe': tipeRiwayat,
        'tanggal': Timestamp.now(),
        'oleh': widget.user.username, // <--- NAMA LENGKAF STAF DIAMBIL DARI MODEL USER
        'keterangan': mode == "Jual" ? 'Barang keluar via Pilihan Manual/Scan' : 'Barang masuk via Pilihan Manual/Scan',
      });

      _showSnackbar("Berhasil! Stok $nama diperbarui.", Colors.green);
    } catch (e) {
      _showSnackbar("Gagal: $e", Colors.red);
    } finally {
      if (mounted) setState(() => isScanCompleted = false);
    }
  }

  void _showErrorDialog({String message = "Gagal!"}) {
    _showSnackbar(message, Colors.red);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => isScanCompleted = false);
    });
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.scanMode == "Jual" ? "Scan Barang Keluar" : "Scan Barang Masuk"),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard),
            tooltip: "Pilih Barang Manual",
            onPressed: _showManualInputDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _processScannedData(barcode.rawValue!);
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(
                  color: widget.scanMode == "Jual" ? Colors.red : Colors.blue, 
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}