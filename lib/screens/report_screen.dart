import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
// --- Tambahan Import ---
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // --- Fungsi Cetak PDF ---
  Future<void> _generateAndPrintPdf(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Text("Laporan Stok Alsakina", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  <String>['Nama Barang', 'Kategori', 'Lokasi', 'Stok'],
                  ...docs.map((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    return [
                      data['nama'] ?? data['nama_busana'] ?? '-',
                      data['kategori'] ?? '-',
                      data['lokasi'] ?? '-',
                      (data['stok'] ?? 0).toString()
                    ];
                  }),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // Fungsi Pintar untuk mengirim pesan restock otomatis
  Future<void> _sendWhatsAppRestock(String namaBarang, int sisaStok) async {
    const String nomorWhatsApp = "6283817090093"; 
    final String pesan = 
        "Halo Gudang/Supplier Alsakina, kami ingin memesan kembali produk * $namaBarang * karena stok di toko saat ini menipis (Sisa $sisaStok Pcs). Mohon segera diproses. Terima kasih!";
    
    final Uri whatsappUri = Uri.parse(
      "https://wa.me/$nomorWhatsApp?text=${Uri.encodeComponent(pesan)}"
    );

    try {
      if (await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tidak dapat membuka aplikasi WhatsApp")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal membuka WhatsApp: $e")));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 700;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Laporan Stok Alsakina",
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
        elevation: 0,
        // --- Tambahan Tombol Print di AppBar ---
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: "Cetak Laporan PDF",
            onPressed: () async {
               var snapshot = await FirebaseFirestore.instance.collection('barang').get();
               if (snapshot.docs.isNotEmpty) {
                 _generateAndPrintPdf(snapshot.docs);
               }
            },
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('barang').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Terjadi kesalahan teknis"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data!.docs;
          
          int totalBarang = docs.length;
          int totalStok = 0;
          int stokMenipisCount = 0;
          Map<String, int> perKategori = {};
          List<Map<String, dynamic>> produkKritis = [];

          for (var doc in docs) {
            var data = doc.data() as Map<String, dynamic>;
            int stok = int.tryParse(data['stok'].toString()) ?? 0;
            String kategori = data['kategori'] ?? 'Lainnya';
            String nama = data['nama_busana'] ?? data['nama'] ?? 'Tanpa Nama';
            String lokasi = data['lokasi'] ?? 'Tidak Ada';

            totalStok += stok;
            perKategori[kategori] = (perKategori[kategori] ?? 0) + stok;

            if (stok <= 5) {
              stokMenipisCount++;
              if (_searchQuery.isEmpty || nama.toLowerCase().contains(_searchQuery.toLowerCase())) {
                produkKritis.add({
                  'nama': nama,
                  'stok': stok,
                  'lokasi': lokasi,
                });
              }
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryHeader(totalBarang, totalStok, stokMenipisCount, isWideScreen),
                const SizedBox(height: 30),
                isWideScreen
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: _buildCategorySection(perKategori, totalStok)),
                          const SizedBox(width: 24),
                          Expanded(flex: 6, child: _buildAlertSection(produkKritis)),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCategorySection(perKategori, totalStok),
                          const SizedBox(height: 25),
                          _buildAlertSection(produkKritis),
                        ],
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildSummaryHeader(int totalJenis, int totalPcs, int menipis, bool isWide) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isWide ? 3 : (constraints.maxWidth > 450 ? 3 : 1),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isWide ? 2.5 : 2.2,
          children: [
            _infoCard("Jenis Busana", totalJenis.toString(), Colors.blue, Icons.checkroom_rounded),
            _infoCard("Total Stok (Pcs)", totalPcs.toString(), Colors.orange, Icons.inventory_2_rounded),
            _infoCard("Stok Menipis (<=5)", menipis.toString(), Colors.red, Icons.warning_amber_rounded),
          ],
        );
      },
    );
  }

  Widget _infoCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))],
        border: Border.all(color: color.withValues(alpha: 0.12), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(Map<String, int> perKategori, int totalStok) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Proporsi Stok Kategori", style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown[800])),
          const Divider(height: 25),
          if (perKategori.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text("Belum ada data barang.")))
          else
            ...perKategori.entries.map((e) => _buildCategoryRow(e.key, e.value, totalStok)),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(String label, int count, int total) {
    double progress = total > 0 ? count / total : 0;
    int percentage = total > 0 ? ((count / total) * 100).round() : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$label ($percentage%)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.grey[800])),
              Text("$count Pcs", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress, backgroundColor: Colors.grey[100], color: Colors.brown[500], minHeight: 10, borderRadius: BorderRadius.circular(6)),
        ],
      ),
    );
  }

  Widget _buildAlertSection(List<Map<String, dynamic>> produkKritis) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red[700]),
              const SizedBox(width: 8),
              Text("Perlu Restock Segera", style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[800])),
            ],
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Cari produk yang menipis.....",
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { setState(() { _searchController.clear(); _searchQuery = ""; }); }) : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const Divider(height: 30),
          if (produkKritis.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Center(child: Text(_searchQuery.isEmpty ? "Aman! Semua stok busana melimpah." : "Produk kritis tidak ditemukan.", style: TextStyle(color: _searchQuery.isEmpty ? Colors.green : Colors.grey))))
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: produkKritis.length,
              separatorBuilder: (context, index) => const Divider(height: 15),
              itemBuilder: (context, index) {
                var item = produkKritis[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(item['nama'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Padding(padding: const EdgeInsets.only(top: 2.0), child: Text("Lokasi: ${item['lokasi']}", style: TextStyle(color: Colors.grey[600]))),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withValues(alpha: 0.2))), child: Text("Sisa ${item['stok']}", style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold))),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.arrow_circle_right_rounded, color: Colors.green, size: 28), tooltip: "Hubungi Supplier via WA", onPressed: () => _sendWhatsAppRestock(item['nama'], item['stok'])),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}