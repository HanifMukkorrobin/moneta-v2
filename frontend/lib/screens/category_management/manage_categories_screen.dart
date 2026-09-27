import 'package:flutter/material.dart';
import '../../models/category_item.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../chat/widgets/transaction_card.dart';

class ManageCategoriesScreen extends StatefulWidget {
  final String initialType;

  const ManageCategoriesScreen({
    super.key,
    this.initialType = 'expense',
  });

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  late String _currentType; // 'expense' or 'income'
  String _filterOwnership = 'all'; // 'all', 'custom', 'default'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Preset icon choices for custom categories
  static const List<IconData> _iconChoices = [
    Icons.fitness_center_rounded,
    Icons.face_retouching_natural_rounded,
    Icons.auto_awesome_rounded,
    Icons.pets_rounded,
    Icons.sports_esports_rounded,
    Icons.coffee_rounded,
    Icons.menu_book_rounded,
    Icons.music_note_rounded,
    Icons.movie_rounded,
    Icons.flight_takeoff_rounded,
    Icons.favorite_rounded,
    Icons.local_cafe_rounded,
    Icons.subscriptions_rounded,
    Icons.shopping_bag_rounded,
    Icons.construction_rounded,
    Icons.school_rounded,
    Icons.volunteer_activism_rounded,
    Icons.savings_rounded,
  ];

  static const List<Color> _colorChoices = [
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.teal,
    Colors.green,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.pink,
    Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();
    _currentType = widget.initialType;
    AppState.instance.addListener(_onStateChange);
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_onStateChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  List<CategoryItem> get _filteredCategories {
    final state = AppState.instance;
    final base = state.categories.where((c) => c.type == _currentType);

    return base.where((cat) {
      // Ownership filter
      if (_filterOwnership == 'custom' && !cat.isCustom) return false;
      if (_filterOwnership == 'default' && !cat.isDefault) return false;

      // Search query
      if (_searchQuery.trim().isNotEmpty) {
        return cat.name.toLowerCase().contains(_searchQuery.toLowerCase().trim());
      }

      return true;
    }).toList();
  }

  int get _customExpenseCount => AppState.instance.customExpenseCategories.length;
  int get _defaultExpenseCount => AppState.instance.defaultExpenseCategories.length;

  void _openAddCategorySheet() {
    final nameController = TextEditingController();
    IconData selectedIcon = _iconChoices.first;
    Color selectedColor = _colorChoices.first;
    String selectedType = _currentType;
    String? errorMessage;

    final quickSuggestions = selectedType == 'expense'
        ? [
            'Gym & Fitness',
            'Skincare',
            'Hobi & Game',
            'Langganan Streaming',
            'Pet Care',
            'Sedekah & Donasi',
            'Buku & Kursus',
          ]
        : [
            'Side Hustle',
            'Dividen Saham',
            'Hadiah',
            'Cashback',
            'Jual Barang Bekas',
          ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(modalContext).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tambah Kategori Sendiri',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Buat kategori pengeluaran personal sesuai kebutuhanmu',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(modalContext),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Type Selector
                            const Text(
                              'Jenis Kategori',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    label: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.arrow_outward_rounded,
                                            size: 15),
                                        SizedBox(width: 4),
                                        Text('Pengeluaran'),
                                      ],
                                    ),
                                    selected: selectedType == 'expense',
                                    selectedColor: AppTheme.expenseColor
                                        .withValues(alpha: 0.15),
                                    onSelected: (val) {
                                      if (val) {
                                        setModalState(() {
                                          selectedType = 'expense';
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ChoiceChip(
                                    label: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.arrow_downward_rounded,
                                            size: 15),
                                        SizedBox(width: 4),
                                        Text('Pemasukan'),
                                      ],
                                    ),
                                    selected: selectedType == 'income',
                                    selectedColor: AppTheme.incomeColor
                                        .withValues(alpha: 0.15),
                                    onSelected: (val) {
                                      if (val) {
                                        setModalState(() {
                                          selectedType = 'income';
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Name Input
                            const Text(
                              'Nama Kategori',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: nameController,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: 'Contoh: Gym, Skincare, Hobi Kamera',
                                prefixIcon: Icon(selectedIcon,
                                    color: selectedColor, size: 20),
                                errorText: errorMessage,
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: Colors.grey.shade300),
                                ),
                              ),
                              onChanged: (_) {
                                if (errorMessage != null) {
                                  setModalState(() => errorMessage = null);
                                }
                              },
                            ),

                            // Quick Suggestions
                            const SizedBox(height: 12),
                            const Text(
                              'Saran Cepat:',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: quickSuggestions.map((suggestion) {
                                return ActionChip(
                                  label: Text(suggestion),
                                  labelStyle: const TextStyle(fontSize: 11),
                                  backgroundColor: Colors.grey.shade100,
                                  onPressed: () {
                                    setModalState(() {
                                      nameController.text = suggestion;
                                      errorMessage = null;
                                    });
                                  },
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 16),

                            // Icon Choices
                            const Text(
                              'Pilih Ikon',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _iconChoices.map((icon) {
                                final isSelected = icon == selectedIcon;
                                return InkWell(
                                  onTap: () {
                                    setModalState(() => selectedIcon = icon);
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? selectedColor.withValues(alpha: 0.15)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected
                                            ? selectedColor
                                            : Colors.grey.shade300,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Icon(
                                      icon,
                                      size: 20,
                                      color: isSelected
                                          ? selectedColor
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 16),

                            // Color Choices
                            const Text(
                              'Pilih Warna',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _colorChoices.map((c) {
                                final isSelected = c == selectedColor;
                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() => selectedColor = c);
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(
                                              color: Colors.white, width: 3)
                                          : null,
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: c.withValues(alpha: 0.5),
                                                blurRadius: 6,
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check,
                                            size: 16, color: Colors.white)
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Submit Button
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: ElevatedButton(
                        onPressed: () {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            setModalState(() {
                              errorMessage = 'Nama kategori tidak boleh kosong';
                            });
                            return;
                          }

                          final success = AppState.instance.addCustomCategory(
                            name,
                            type: selectedType,
                            icon: selectedIcon,
                            color: selectedColor,
                          );

                          if (!success) {
                            setModalState(() {
                              errorMessage =
                                  'Kategori dengan nama ini sudah ada';
                            });
                            return;
                          }

                          Navigator.pop(modalContext);
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Kategori "$name" berhasil ditambahkan!'),
                                ],
                              ),
                              backgroundColor: AppTheme.primaryColor,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Simpan Kategori',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openEditCategoryDialog(CategoryItem category) {
    final nameController = TextEditingController(text: category.name);
    IconData selectedIcon = category.icon ?? Icons.bookmark_border_rounded;
    Color selectedColor = category.color ?? Colors.purple;
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: const Text('Ubah Nama Kategori'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: 'Nama Kategori',
                      errorText: errorText,
                      prefixIcon: Icon(selectedIcon, color: selectedColor),
                    ),
                    onChanged: (_) {
                      if (errorText != null) {
                        setDialogState(() => errorText = null);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Pilih Ikon Baru:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _iconChoices.take(8).map((icon) {
                        final isSelected = icon == selectedIcon;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () {
                              setDialogState(() => selectedIcon = icon);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? selectedColor.withValues(alpha: 0.15)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? selectedColor
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Icon(icon,
                                  size: 18,
                                  color: isSelected
                                      ? selectedColor
                                      : Colors.grey.shade700),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newName = nameController.text.trim();
                    if (newName.isEmpty) {
                      setDialogState(() =>
                          errorText = 'Nama kategori tidak boleh kosong');
                      return;
                    }

                    final success = AppState.instance.updateCategory(
                      category.id,
                      newName,
                      icon: selectedIcon,
                      color: selectedColor,
                    );

                    if (!success) {
                      setDialogState(() =>
                          errorText = 'Nama kategori sudah digunakan');
                      return;
                    }

                    Navigator.pop(dialogCtx);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Kategori diubah menjadi "$newName"'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleDeleteCategory(CategoryItem category) async {
    final count =
        AppState.instance.getTransactionCountForCategory(category.name);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kategori Sendiri?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin menghapus kategori "${category.name}"?',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            if (count > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ada $count transaksi menggunakan kategori ini. Transaksi akan dialihkan ke kategori "Lainnya".',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expenseColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final success = AppState.instance.deleteCategory(category.id);
      if (success) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kategori "${category.name}" berhasil dihapus'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _filteredCategories;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Kelola Kategori Sendiri',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              'Kategori Pengeluaran & Pemasukan Kustom',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
            tooltip: 'Tambah Kategori Sendiri',
            onPressed: _openAddCategorySheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Info & Stats Banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.shade700,
                  Colors.deepPurple.shade600,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bookmark_add_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_customExpenseCount Kategori Sendiri • $_defaultExpenseCount Bawaan',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kategori kustom melatih AI mengenali gaya pengeluaranmu secara akurat.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _openAddCategorySheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.purple.shade800,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    '+ Buat',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
              decoration: InputDecoration(
                hintText: 'Cari kategori...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),

          // Filters: Type (Expense / Income) & Ownership (All / Custom / Default)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                // Type Filter
                ChoiceChip(
                  label: const Text('Pengeluaran'),
                  selected: _currentType == 'expense',
                  selectedColor: AppTheme.expenseColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _currentType == 'expense'
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _currentType == 'expense'
                        ? AppTheme.expenseColor
                        : Colors.grey.shade700,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _currentType = 'expense');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Pemasukan'),
                  selected: _currentType == 'income',
                  selectedColor: AppTheme.incomeColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _currentType == 'income'
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _currentType == 'income'
                        ? AppTheme.incomeColor
                        : Colors.grey.shade700,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _currentType = 'income');
                  },
                ),

                const SizedBox(width: 10),
                Container(height: 18, width: 1, color: Colors.grey.shade300),
                const SizedBox(width: 10),

                // Ownership Filters
                _buildOwnershipChip('all', 'Semua (${_filteredCategoriesCount('all')})'),
                const SizedBox(width: 6),
                _buildOwnershipChip('custom', 'Kategori Sendiri (${_filteredCategoriesCount('custom')})'),
                const SizedBox(width: 6),
                _buildOwnershipChip('default', 'Bawaan (${_filteredCategoriesCount('default')})'),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Category List
          Expanded(
            child: categories.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80, top: 4),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final txCount = AppState.instance
                          .getTransactionCountForCategory(cat.name);

                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: cat.isCustom
                                ? Colors.purple.shade200
                                : AppTheme.borderSubtle,
                            width: cat.isCustom ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: (cat.color ??
                                      (cat.isExpense
                                          ? AppTheme.expenseColor
                                          : AppTheme.incomeColor))
                                  .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              cat.icon ??
                                  TransactionCard.getCategoryIcon(
                                      cat.name, cat.isExpense),
                              color: cat.color ??
                                  (cat.isExpense
                                      ? AppTheme.expenseColor
                                      : AppTheme.incomeColor),
                              size: 20,
                            ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  cat.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: cat.isCustom
                                      ? Colors.purple.shade50
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: cat.isCustom
                                        ? Colors.purple.shade200
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  cat.isCustom ? 'Kategori Sendiri' : 'Bawaan',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: cat.isCustom
                                        ? Colors.purple.shade800
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              txCount > 0
                                  ? '$txCount transaksi menggunakan kategori ini'
                                  : 'Belum ada transaksi',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          trailing: cat.isCustom
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18),
                                      color: AppTheme.primaryColor,
                                      tooltip: 'Ubah Kategori',
                                      onPressed: () =>
                                          _openEditCategoryDialog(cat),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18),
                                      color: Colors.red.shade400,
                                      tooltip: 'Hapus Kategori',
                                      onPressed: () =>
                                          _handleDeleteCategory(cat),
                                    ),
                                  ],
                                )
                              : const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddCategorySheet,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Kategori Sendiri',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  int _filteredCategoriesCount(String ownership) {
    final state = AppState.instance;
    final base = state.categories.where((c) => c.type == _currentType);
    if (ownership == 'custom') return base.where((c) => c.isCustom).length;
    if (ownership == 'default') return base.where((c) => c.isDefault).length;
    return base.length;
  }

  Widget _buildOwnershipChip(String value, String label) {
    final isSelected = _filterOwnership == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryLight.withValues(alpha: 0.15),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade700,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
      ),
      visualDensity: VisualDensity.compact,
      onSelected: (selected) {
        if (selected) setState(() => _filterOwnership = value);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark_border_rounded,
                size: 48,
                color: Colors.purple.shade400,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tidak ada kategori ditemukan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Coba sesuaikan kata kunci pencarian atau buat kategori baru.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openAddCategorySheet,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Tambah Kategori Sendiri'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
