import '../models/debt_item.dart';

class DebtMockData {
  static List<DebtItem> getInitialDebts() {
    final now = DateTime.now();
    return [
      DebtItem(
        id: 'debt_1',
        name: 'Paylater Belanja Online (Spay)',
        totalAmount: 1250000,
        remainingAmount: 450000,
        dueDate: now.add(const Duration(days: 2)),
        status: 'active',
        type: DebtType.paylater,
        notes: 'Belanja perlengkapan rumah & elektronik ringan',
      ),
      DebtItem(
        id: 'debt_2',
        name: 'Cicilan Laptop Kerja (Bulan 3/6)',
        totalAmount: 6000000,
        remainingAmount: 3000000,
        dueDate: now.add(const Duration(days: 12)),
        status: 'active',
        type: DebtType.cicilan,
        notes: 'Tenor 6 bulan cicilan 0% keperluan kantor',
      ),
      DebtItem(
        id: 'debt_3',
        name: 'Tagihan Kartu Kredit Bank BCA',
        totalAmount: 850000,
        remainingAmount: 850000,
        dueDate: now.add(const Duration(days: 1)),
        status: 'active',
        type: DebtType.kartuKredit,
        notes: 'Transaksi groceries & bensin pertengahan bulan',
      ),
      DebtItem(
        id: 'debt_4',
        name: 'Pinjaman Teman (Budi - Talangan)',
        totalAmount: 300000,
        remainingAmount: 0,
        dueDate: now.subtract(const Duration(days: 5)),
        status: 'paid',
        type: DebtType.pinjamanPribadi,
        notes: 'Talangan beli tiket kereta pulang kampung',
      ),
      DebtItem(
        id: 'debt_5',
        name: 'Paylater Tagihan Listrik (Kredivo)',
        totalAmount: 275000,
        remainingAmount: 0,
        dueDate: now.subtract(const Duration(days: 7)),
        status: 'paid',
        type: DebtType.paylater,
        notes: 'Token listrik PLN 500rb awal bulan',
      ),
    ];
  }
}
