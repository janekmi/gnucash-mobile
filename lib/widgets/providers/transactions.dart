import 'dart:collection';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:csv/csv_settings_autodetection.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class Transaction {
  String date;
  String id;
  int number;
  String description;
  String notes;
  String commodityCurrency;
  String voidReason;
  String action;
  String memo;
  String fullAccountName;
  String accountName;
  String amountWithSymbol;
  double amount;
  String reconcile = "n";
  String reconcileDate;
  int ratePrice;

  Transaction();

  Transaction.fromList(List<dynamic> items) {
    final trimmed = [];
    for (var item in items) {
      trimmed.add(item.trim());
    }

    date = trimmed[0] ?? "";
    id = trimmed[1];
    number = int.tryParse(trimmed[2]);
    description = trimmed[3];
    notes = trimmed[4];
    commodityCurrency = trimmed[5];
    voidReason = trimmed[6];
    action = trimmed[7];
    memo = trimmed[8];
    fullAccountName = trimmed[9];
    accountName = trimmed[10];
    amountWithSymbol = trimmed[11];
    amount = double.tryParse(trimmed[12]);
    reconcile = trimmed[13];
    reconcileDate = trimmed[14];
    ratePrice = int.tryParse(trimmed[15]);
  }

  @override
  toString() {
    return """Transaction{date: ${date}, id: ${id}, number: ${number}, description: ${description}, notes: ${notes}, commodityCurrency: ${commodityCurrency}, voidReason: ${voidReason}, action: ${action}, memo: ${memo}, fullAccountName: ${fullAccountName}, accountName: ${accountName}, amountWithSymbol: ${amountWithSymbol}, amount: ${amount}, reconcile: ${reconcile}, reconcileDate: ${reconcileDate}, ratePrice: ${ratePrice}}""";
  }

  List<dynamic> toList() {
    return [
      date ?? "",
      id ?? "",
      number ?? "",
      description ?? "",
      notes ?? "",
      commodityCurrency ?? "",
      voidReason ?? "",
      action ?? "",
      memo ?? "",
      fullAccountName ?? "",
      accountName ?? "",
      amountWithSymbol ?? "",
      amount ?? "",
      reconcile ?? "",
      reconcileDate ?? "",
      ratePrice ?? ""
    ];
  }
}

class TransactionsModel extends ChangeNotifier {
  Future<String> get _localPath async {
    final directory = await getApplicationSupportDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/transactions.csv');
  }

  Future<String> readTransactionsCsv() async {
    try {
      final file = await _localFile;
      final string = await file.readAsString();
      return "Date,Transaction ID,Number,Description,Notes,Commodity/Currency,Void Reason,Action,Memo,Full Account Name,Account Name,Amount With Sym.,Amount Num,Reconcile,Reconcile Date,Rate/Price\n$string";
    } catch (e) {
      print("readTransactionsCsv error");
      print(e);
      return null;
    }
  }

  Map<String, List<Transaction>> _transactionsByAccountFullName = {};

  UnmodifiableMapView<String, List<Transaction>>
      get transactionsByAccountFullName {
    return UnmodifiableMapView(_transactionsByAccountFullName);
  }

  Future<UnmodifiableListView<Transaction>> get transactions async {
    try {
      final file = await _localFile;
      String contents = await file.readAsString();

      var detector = FirstOccurrenceSettingsDetector(
        eols: ['\r\n', '\n'],
      );

      final converter = CsvToListConverter(
        csvSettingsDetector: detector,
        textDelimiter: '"',
        shouldParseNumbers: false,
      );

      final parsed = converter.convert(contents.trim());

      final transactions = <Transaction>[];
      final Map<String, List<Transaction>> transactionsByAccountFullName =
          {};
      for (var line in parsed) {
        final transaction = Transaction.fromList(line);
        transactions.add(transaction);

        // Add to representation of balances
        if (transactionsByAccountFullName
            .containsKey(transaction.fullAccountName)) {
          transactionsByAccountFullName[transaction.fullAccountName]
              .add(transaction);
        } else {
          transactionsByAccountFullName[transaction.fullAccountName] = [
            transaction
          ];
        }
      }

      this._transactionsByAccountFullName = transactionsByAccountFullName;

      return UnmodifiableListView(transactions);
    } catch (e) {
      print("readTransactions error");
      print(e);
      return null;
    }
  }

  void addAll(List<Transaction> transactions) async {
    final file = await _localFile;
    final csvString = const ListToCsvConverter(eol: "\n")
        .convert(transactions.map((t) => t.toList()).toList());

    try {
      file.writeAsString(
        "$csvString\n",
        mode: FileMode.append,
      );
    } catch (e) {
      print("addAll error");
      print(e);
    }

    // Add to representation of balances
    for (var _transaction in transactions) {
      if (_transactionsByAccountFullName
          .containsKey(_transaction.fullAccountName)) {
        _transactionsByAccountFullName[_transaction.fullAccountName]
            .add(_transaction);
      } else {
        _transactionsByAccountFullName[_transaction.fullAccountName] = [
          _transaction
        ];
      }
    }

    notifyListeners();
  }

  void removeAll() async {
    final file = await _localFile;

    try {
      file.delete();
    } catch (e) {
      print(e);
    }

    _transactionsByAccountFullName.clear();

    notifyListeners();
  }

  Future<bool> remove(Transaction transaction) async {
    try {
      final file = await _localFile;
      final lines = await file.readAsLines();

      final toRemove = [];
      for (var line in lines) {
        if (line.contains(transaction.id)) {
          toRemove.add(line);
        }
      }

      if (toRemove.isEmpty) {
        return false;
      }

      for (var line in toRemove) {
        lines.remove(line);
      }

      file.writeAsString(lines.toString());

      // TODO: Remove this hack attack-y way of refreshing the transactions state
      _transactionsByAccountFullName.clear();
      await transactions;

      notifyListeners();

      return true;
    } catch (err) {
      print("removeTransaction error");
      print(err);

      return false;
    }
  }
}
