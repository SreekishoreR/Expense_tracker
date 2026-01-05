import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/expense.dart';

import 'firebase_options.dart';
import 'providers/expense_provider.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => ExpenseProvider(),
      child: const ExpenseTrackerApp(),
    ),
  );
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFC9B59C),      // accent
    background: const Color(0xFFF9F8F6),     // main background
  ),
  scaffoldBackgroundColor: const Color(0xFFF9F8F6),
),

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            // user logged in
            return const HomeScreen();
          }
          // user NOT logged in
          return const LoginScreen();
        },
      ),
    );
  }
}

// ---------------------- HOME SCREEN ----------------------

enum ExpenseFilter { all, today, month }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();

  ExpenseFilter _selectedFilter = ExpenseFilter.all;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final provider = context.read<ExpenseProvider>();
      provider.fetchCategories();
      provider.fetchExpenses();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void _openAddExpenseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        // listen for category changes using ctx.watch
        final categories = ctx.watch<ExpenseProvider>().categories;

        // if nothing selected yet, pick first available
        if (categories.isNotEmpty && _selectedCategory == null) {
          _selectedCategory = categories.first;
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Expense',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // TITLE
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // AMOUNT
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // CATEGORY DROPDOWN
                DropdownButtonFormField<String>(
                  value: _selectedCategory ??
                      (categories.isNotEmpty ? categories.first : null),
                  items: categories
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c, child: Text(c)),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                ),

                // ADD NEW CATEGORY BUTTON
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      final newCat = await _showAddCategoryDialog(ctx);
                      if (newCat != null && newCat.trim().isNotEmpty) {
                        final trimmed = newCat.trim();

                        await ctx
                            .read<ExpenseProvider>()
                            .addCategory(trimmed);

                        setState(() {
                          _selectedCategory = trimmed;
                        });
                      }
                    },
                    child: const Text('Add new category'),
                  ),
                ),

                const SizedBox(height: 12),

                // DATE PICKER
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: _selectedDate,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 1),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _selectedDate.toLocal().toString().split(' ')[0],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // BUTTONS
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addExpenseFromForm,
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _addExpenseFromForm() {
    final title = _titleController.text.trim();
    final amountText = _amountController.text.trim();

    if (title.isEmpty || amountText.isEmpty) {
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      return;
    }

    final expenseProvider = context.read<ExpenseProvider>();

    final category = _selectedCategory ??
        (expenseProvider.categories.isNotEmpty
            ? expenseProvider.categories.first
            : 'General');

    expenseProvider.addExpense(title, amount, category, _selectedDate);

    _titleController.clear();
    _amountController.clear();
    _selectedDate = DateTime.now();
    Navigator.of(context).pop();
  }

  Future<String?> _showAddCategoryDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('New Category'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Category name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _openCategoryManager() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final categories =
                ctx.watch<ExpenseProvider>().categories;

            return ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final canDelete =
                    categories.length > 1 && cat != 'General';

                return ListTile(
                  title: Text(cat),
                  trailing: canDelete
                      ? IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            await ctx
                                .read<ExpenseProvider>()
                                .deleteCategory(cat);
                            setModalState(() {});
                          },
                        )
                      : null,
                );
              },
            );
          },
        );
      },
    );
  }
  List<Expense> _getFilteredExpenses(List<Expense> all) {
  final now = DateTime.now();

  switch (_selectedFilter) {
    case ExpenseFilter.today:
      return all
          .where((e) =>
              e.date.year == now.year &&
              e.date.month == now.month &&
              e.date.day == now.day)
          .toList();
    case ExpenseFilter.month:
      return all
          .where((e) =>
              e.date.year == now.year &&
              e.date.month == now.month)
          .toList();
    case ExpenseFilter.all:
    default:
      return all;
  }
}

Widget _buildFilterChips() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Row(
      children: [
        // ALL
        ChoiceChip(
          label: const Text('All'),
          selected: _selectedFilter == ExpenseFilter.all,
          selectedColor: const Color(0xFFC9B59C),
          backgroundColor: const Color(0xFFD9CFC7),
          labelStyle: TextStyle(
            color: _selectedFilter == ExpenseFilter.all
                ? Colors.white
                : Colors.black87,
          ),
          onSelected: (_) {
            setState(() {
              _selectedFilter = ExpenseFilter.all;
            });
          },
        ),
        const SizedBox(width: 8),

        // TODAY
        ChoiceChip(
          label: const Text('Today'),
          selected: _selectedFilter == ExpenseFilter.today,
          selectedColor: const Color(0xFFC9B59C),
          backgroundColor: const Color(0xFFD9CFC7),
          labelStyle: TextStyle(
            color: _selectedFilter == ExpenseFilter.today
                ? Colors.white
                : Colors.black87,
          ),
          onSelected: (_) {
            setState(() {
              _selectedFilter = ExpenseFilter.today;
            });
          },
        ),
        const SizedBox(width: 8),

        // THIS MONTH
        ChoiceChip(
          label: const Text('This month'),
          selected: _selectedFilter == ExpenseFilter.month,
          selectedColor: const Color(0xFFC9B59C),
          backgroundColor: const Color(0xFFD9CFC7),
          labelStyle: TextStyle(
            color: _selectedFilter == ExpenseFilter.month
                ? Colors.white
                : Colors.black87,
          ),
          onSelected: (_) {
            setState(() {
              _selectedFilter = ExpenseFilter.month;
            });
          },
        ),
      ],
    ),
  );
}



  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final expenses = expenseProvider.expenses;
    final total = expenseProvider.totalAmount;
    final totalToday = expenseProvider.totalToday;
    final totalThisMonth = expenseProvider.totalThisMonth;
    final filteredExpenses = _getFilteredExpenses(expenses);


    return Scaffold(
  appBar: AppBar(
    elevation: 0,
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.black87,
    centerTitle: false,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Expense Tracker',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        Text(
          'Total: ₹${total.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    ),
  ),
  backgroundColor: const Color(0xFFF9F8F6),

      body: Stack(
        children: [
          Positioned.fill(
  child: filteredExpenses.isEmpty
      ? Column(
          children: [
            _SummaryCard(
              totalToday: totalToday,
              totalThisMonth: totalThisMonth,
            ),

            // 🔹 Filter chips even when empty
            _buildFilterChips(),

            const Expanded(
              child: Center(
                child: Text('No expenses to show. Try changing the filter or add one with +'),
              ),
            ),
          ],
        )
      : Column(
          children: [
            _SummaryCard(
              totalToday: totalToday,
              totalThisMonth: totalThisMonth,
            ),

            // 🔹 Filter chips above list
            _buildFilterChips(),

            Expanded(
              child: ListView.builder(
                itemCount: filteredExpenses.length,
                itemBuilder: (context, index) {
                  final expense = filteredExpenses[index];
                  return Card(
  color: const Color(0xFFEFE9E3),     // palette #2
  margin: const EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 4,
  ),
  child: ListTile(
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFD9CFC7), // palette #3
      child: Text(
        expense.category[0].toUpperCase(),
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black,
        ),
      ),
    ),
    title: Text(
      expense.title,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: Text(
      '${expense.category} • ${expense.date.toLocal().toString().split(' ')[0]}',
    ),
    trailing: Text(
      '₹${expense.amount.toStringAsFixed(2)}',
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: Color(0xFFC9B59C),      // accent
      ),
    ),
    onLongPress: () {
      context.read<ExpenseProvider>().deleteExpense(expense.id);
    },
  ),
);

                },
              ),
            ),
          ],
        ),
),


          // Small grey buttons above the +
          Positioned(
  right: 16,
  bottom: 120,
  child: Column(
    children: [
      // Logout (top)
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEFE9E3),      // palette #2 surface
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.logout_outlined, size: 20),
          color: const Color(0xFFC9B59C),      // accent
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
          onPressed: _logout,
        ),
      ),
      const SizedBox(height: 14),
      // Categories (bottom)
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEFE9E3),      // palette #2 surface
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.category_outlined, size: 20),
          color: const Color(0xFFC9B59C),      // accent
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(),
          onPressed: _openCategoryManager,
        ),
      ),
    ],
  ),
),


        ],
      ),
      floatingActionButton: FloatingActionButton(
    backgroundColor: const Color(0xFFC9B59C), // accent
    foregroundColor: Colors.white,
    onPressed: _openAddExpenseSheet,
    child: const Icon(Icons.add),
  ),
);
  }
}

// ---------------------- SUMMARY CARD ----------------------

class _SummaryCard extends StatelessWidget {
  final double totalToday;
  final double totalThisMonth;

  const _SummaryCard({
    required this.totalToday,
    required this.totalThisMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
  color: const Color(0xFFEFE9E3),    // palette #2 surface
  borderRadius: BorderRadius.circular(16),
  boxShadow: [
    BoxShadow(
      blurRadius: 6,
      offset: const Offset(0, 3),
      color: Colors.black.withOpacity(0.05),
    ),
  ],
),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Today
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Today',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${totalToday.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC9B59C),
                ),
              ),
            ],
          ),
          // This month
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'This month',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${totalThisMonth.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC9B59C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
