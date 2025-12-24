import 'dart:collection';
import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:csv/csv_settings_autodetection.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Account {
  double balance = 0.0; // non-standard
  List<Account> children = []; // non-standard
  late String code;
  late String commodityM;
  late String commodityN;
  late String color;
  late String description;
  late String fullName;
  late bool hidden;
  late String notes;
  late String parentFullName; // non-standard
  late bool placeholder; // Whether transactions can be placed in this account?
  late bool tax;
  late String type;
  late String name;

  Account.fromJson(Map<String, dynamic> json) {
    balance = json['balance'];
    children = [];
    if (json['children'] != null) {
      final List<dynamic> rawChildren = json['children'];
      for (var element in rawChildren) {
        children.add(Account.fromJson(element));
      }
    }
    code = json['code'];
    commodityM = json['commodityM'];
    commodityN = json['commodityN'];
    color = json['color'];
    description = json['description'];
    fullName = json['fullName'];
    hidden = json['hidden'];
    name = json['name'];
    notes = json['notes'];
    parentFullName = json['parentFullName'];
    placeholder = json['placeholder'];
    tax = json['tax'];
    type = json['type'];
  }

  Map<String, dynamic> toJson() {
    final json = {
      'balance': balance,
      'children': children,
      'code': code,
      'commodityM': commodityM,
      'commodityN': commodityN,
      'color': color,
      'description': description,
      'fullName': fullName,
      'hidden': hidden,
      'name': name,
      'notes': notes,
      'parentFullName': parentFullName,
      'placeholder': placeholder,
      'tax': tax,
      'type': type
    };

    return json;
  }

  Account.fromList(List<dynamic> items) {
    final trimmed = [];
    for (var item in items) {
      trimmed.add(item.trim());
    }

    type = trimmed[0];
    fullName = trimmed[1];
    name = trimmed[2];
    code = trimmed[3];
    description = trimmed[4];
    color = trimmed[5];
    notes = trimmed[6];
    commodityM = trimmed[7];
    commodityN = trimmed[8];
    hidden = trimmed[9] == 'T' ? true : false;
    tax = trimmed[10] == 'T' ? true : false;
    placeholder = trimmed[11] == 'T' ? true : false;
  }

  @override
  toString() {
    return "Account{balance: ${balance}, children: List<Account>[${children ?? [].length}], code: ${code}, commodityM: ${commodityM}, commodityN: ${commodityN}, color: ${color}, description: ${description}, fullName: ${fullName}, hidden: ${hidden}, notes: ${notes}, parentFullName: ${parentFullName}, placeholder: ${placeholder}, tax: ${tax}, type: ${type}, name: ${name}}";
  }
}

class AccountsModel extends ChangeNotifier {
  final _prefs = SharedPreferences.getInstance();

  Future<String> get _localPath async {
    final directory = await getApplicationSupportDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/accounts.csv');
  }

  List<Account> _validTransactionAccounts = [];

  Future<Account> get favoriteDebitAccount async {
    final prefs = await _prefs;
    final favoriteDebitAccountString = prefs.getString('favoriteDebitAccount');

    if (favoriteDebitAccountString != null) {
      return Account.fromJson(jsonDecode(favoriteDebitAccountString));
    } else {
      return null;
    }
  }

  void setFavoriteDebitAccount(Account account) async {
    final prefs = await _prefs;
    await prefs.setString('favoriteDebitAccount', jsonEncode(account));

    notifyListeners();
  }

  void removeFavoriteDebitAccount() async {
    final prefs = await _prefs;
    await prefs.remove('favoriteDebitAccount');

    notifyListeners();
  }

  Future<Account> get favoriteCreditAccount async {
    final prefs = await _prefs;
    final favoriteCreditAccountString =
        prefs.getString('favoriteCreditAccount');

    if (favoriteCreditAccountString != null) {
      return Account.fromJson(jsonDecode(favoriteCreditAccountString));
    } else {
      return null;
    }
  }

  void setFavoriteCreditAccount(Account account) async {
    final prefs = await _prefs;
    await prefs.setString('favoriteCreditAccount', jsonEncode(account));

    notifyListeners();
  }

  void removeFavoriteCreditAccount() async {
    final prefs = await _prefs;
    await prefs.remove('favoriteCreditAccount');

    notifyListeners();
  }

  final List<Account> _recentCreditAccounts = [];
  final List<Account> _recentDebitAccounts = [];
  late List<Account> _accounts;

  UnmodifiableListView<Account> get validTransactionAccounts =>
      UnmodifiableListView(_validTransactionAccounts);
  UnmodifiableListView<Account> get recentCreditAccounts =>
      UnmodifiableListView(_recentCreditAccounts);
  UnmodifiableListView<Account> get recentDebitAccounts =>
      UnmodifiableListView(_recentDebitAccounts);

  List<Account> parseAccountCSV(String csv) {
    var detector = FirstOccurrenceSettingsDetector(
      eols: ['\r\n', '\n'],
    );

    final converter = CsvToListConverter(
      csvSettingsDetector: detector,
      textDelimiter: '"',
      shouldParseNumbers: false,
    );

    final parsed = converter.convert(csv.trim());
    // Remove header row
    parsed.removeAt(0);

    final accounts = <Account>[];
    final transactionAccounts = <Account>[];
    for (var line in parsed) {
      final account = Account.fromList(line);
      final lastIndex = account.fullName.lastIndexOf(":");
      final hasParent = lastIndex > 0;
      var parentFullName = '';
      if (hasParent) {
        parentFullName = account.fullName.substring(0, lastIndex);
      }

      account.parentFullName = parentFullName;
      accounts.add(account);

      if (!account.placeholder) {
        // This account is valid to make transactions to/from
        transactionAccounts.add(account);
      }
    }
    _validTransactionAccounts = transactionAccounts;

    final lookup = <String, Account>{};
    final List<Account> hierarchicalAccounts = [];

    for (var _account in accounts) {
      if (lookup.containsKey(_account.parentFullName)) {
        final parent = lookup[_account.parentFullName];
        parent!.children.add(_account);
      } else {
        hierarchicalAccounts.add(_account);
      }

      lookup[_account.fullName] = _account;
    }
    return hierarchicalAccounts;
  }

  Future<List<Account>> get accounts async {
    final file = await _localFile;
    String csvString = await file.readAsString();
    final parsedAccounts = parseAccountCSV(csvString);
    _accounts = parsedAccounts;

    return parsedAccounts;
  }

  Account getAccountByFullName(String fullName) {
    return _accounts.firstWhere((element) => element.fullName == fullName);
  }

  void addAll(String csv) async {
    final file = await _localFile;
    file.writeAsString(csv);

    notifyListeners();
  }

  void removeAll() async {
    final file = await _localFile;
    file.delete();

    notifyListeners();
  }
}
