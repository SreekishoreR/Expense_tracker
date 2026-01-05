import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../models/expense.dart';

class ExpenseProvider with ChangeNotifier {
  final _db = FirebaseDatabase.instance.ref();

   // Categories list (start with some defaults, user can change later)
  final List<String> _categories = [
    'General',
    'Food',
    'Transport',
    'Shopping',
    'Entertainment',
  ];

  List<String> get categories => List.unmodifiable(_categories);
  final List<Expense> _expenses = [];


  // public read-only list
  List<Expense> get expenses => List.unmodifiable(_expenses);

  double get totalAmount {
    double sum = 0;
    for (var e in _expenses) {
      sum += e.amount;
    }
    return sum;
  }

  double get totalToday {
  final now = DateTime.now();
  double sum = 0;

  for (var e in _expenses) {
    if (e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day) {
      sum += e.amount;
    }
  }

  return sum;
}

double get totalThisMonth {
  final now = DateTime.now();
  double sum = 0;

  for (var e in _expenses) {
    if (e.date.year == now.year && e.date.month == now.month) {
      sum += e.amount;
    }
  }

  return sum;
}


    void addExpense(String title, double amount, String category, DateTime date) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newExpense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      amount: amount,
      date: date,
      category: category,
    );

    // Save to Firebase
    _db.child("users/${user.uid}/expenses/${newExpense.id}").set({
      "title": newExpense.title,
      "amount": newExpense.amount,
      "date": newExpense.date.toIso8601String(),
      "category": newExpense.category,
    });

    // Local update
    _expenses.insert(0, newExpense);
    notifyListeners();
  }


Future<void> fetchExpenses() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final snapshot = await _db.child("users/${user.uid}/expenses").get();

  _expenses.clear(); // clear old data

  if (snapshot.exists && snapshot.value != null) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);

    data.forEach((key, value) {
      final expenseMap = Map<String, dynamic>.from(value as Map);

      _expenses.add(
        Expense(
          id: key,
          title: expenseMap["title"] as String,
          amount: (expenseMap["amount"] as num).toDouble(),
          date: DateTime.parse(expenseMap["date"] as String),
          category: expenseMap["category"] as String,
        ),
      );
    });
  }

  notifyListeners();
}

  Future<void> deleteExpense(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // delete from firebase
    await _db.child("users/${user.uid}/expenses/$id").remove();

    // delete locally
    _expenses.removeWhere((e) => e.id == id);
    notifyListeners();
  }

    Future<void> fetchCategories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await _db.child("users/${user.uid}/categories").get();

    if (snapshot.exists && snapshot.value != null) {
      final raw = snapshot.value;
      _categories.clear();

      // we’ll store categories as a list in Firebase
      final list = List.from(raw as List);
      for (var item in list) {
        if (item is String && item.trim().isNotEmpty) {
          _categories.add(item);
        }
      }
    } else {
      // if no categories saved yet, save the current defaults to Firebase
      await _db.child("users/${user.uid}/categories").set(_categories);
    }

    notifyListeners();
  }

  Future<void> addCategory(String name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_categories.contains(trimmed)) return;

    _categories.add(trimmed);
    await _db.child("users/${user.uid}/categories").set(_categories);
    notifyListeners();
  }

  Future<void> deleteCategory(String name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // don't allow deleting the last category
    if (_categories.length <= 1) return;

    _categories.remove(name);
    await _db.child("users/${user.uid}/categories").set(_categories);
    notifyListeners();
  }


}
