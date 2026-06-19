import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Pastikan package intl ada di pubspec.yaml

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Riwayat Stok"),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Mengambil data riwayat urut berdasarkan tanggal terbaru
        stream: FirebaseFirestore.instance
            .collection('riwayat')
            .orderBy('tanggal', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Terjadi kesalahan data"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Belum ada riwayat stok"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              
              // Penanganan Format Tanggal
              String formatTanggal = "-";
              if (data['tanggal'] != null) {
                DateTime tanggal = (data['tanggal'] as Timestamp).toDate();
                formatTanggal = DateFormat('dd MMM yyyy, HH:mm').format(tanggal);
              }
              
              // Ekstraksi data
              String namaBarang = data['nama_barang'] ?? 'Produk Tanpa Nama';
              String kodeBarang = data['kode_barang'] ?? '---';
              String tipe = data['tipe'] ?? 'Update';
              int jumlahStok = int.tryParse(data['jumlah'].toString()) ?? 0;
              
              // PERBAIKAN: Mengambil data dari field 'oleh' agar sesuai dengan ScannerScreen
              String operatorName = data['oleh'] ?? 'Admin';

              // Logika deteksi penambahan stok
              bool isStokTambah = tipe.contains('Stok Awal') || tipe.contains('Masuk') || tipe.contains('Restock');

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isStokTambah ? Colors.green[100] : Colors.blue[100],
                    child: Icon(
                      isStokTambah ? Icons.add_business : Icons.sync,
                      color: isStokTambah ? Colors.green[800] : Colors.blue[800],
                    ),
                  ),
                  title: Text(
                    "$namaBarang ($kodeBarang)",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        "Aksi: $tipe - Jumlah: $jumlahStok",
                        style: TextStyle(color: Colors.grey[800], fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person, size: 14, color: Colors.brown[600]),
                          const SizedBox(width: 4),
                          Text(
                            "Oleh: $operatorName",
                            style: TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.w600, 
                              color: Colors.brown[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatTanggal,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: Text(
                    isStokTambah ? "+$jumlahStok" : "$jumlahStok",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isStokTambah ? Colors.green[700] : Colors.blue[700],
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}