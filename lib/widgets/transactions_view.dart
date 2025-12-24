import 'package:flutter/material.dart';
import 'package:gnucash_mobile/providers/transactions.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TransactionsView extends StatelessWidget {
  final List<Transaction> transactions;

  const TransactionsView({super.key, required this.transactions});


  @override
  Widget build(BuildContext context) {
    final simpleCurrencyNumberFormat = NumberFormat.simpleCurrency(
        locale: Localizations.localeOf(context).toString());

    return Consumer<TransactionsModel>(builder: (context, transactions, child) {
      final transactionsBuilder = ListView.builder(
        itemBuilder: (context, index) {
          if (index.isOdd) {
            return Divider();
          }

          final int i = index ~/ 2;
          if (i >= this.transactions.length) {
            return null;
          }

          final transaction = this.transactions[i];
          final simpleCurrencyValue = simpleCurrencyNumberFormat
              .format(simpleCurrencyNumberFormat.parse(transaction.amount.toString()));
          return Dismissible(
            background: Container(color: Colors.red),
            key: Key(transaction.description + transaction.fullAccountName),
            onDismissed: (direction) async {
              transactions.remove(transaction);
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text("Transaction removed.")));
            },
            child: ListTile(
                title: Text(
                  transaction.description,
                ),
                trailing: Text(simpleCurrencyValue),
                onTap: () {
                  print(transaction);
                }),
          );
        },
        padding: EdgeInsets.all(16.0),
        shrinkWrap: true,
      );

      return Container(
        child: this.transactions.isNotEmpty
            ? transactionsBuilder
            : Center(child: Text("No transactions.")),
      );
    });
  }
}
