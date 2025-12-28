import 'package:flutter/material.dart';
import 'package:gnucash_mobile/providers/accounts.dart';
import 'package:gnucash_mobile/providers/transactions.dart';
import 'package:gnucash_mobile/widgets/transaction_form.dart';
import 'package:gnucash_mobile/widgets/transactions_view.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import 'account_view.dart';

class ListOfAccounts extends StatelessWidget {
  final List<Account> accounts;

  const ListOfAccounts({super.key, required this.accounts});

  @override
  Widget build(BuildContext context) {
    final simpleCurrencyNumberFormat = NumberFormat.simpleCurrency(
        locale: Localizations.localeOf(context).toString());

    return Container(
      child: Consumer<TransactionsModel>(
          builder: (context, transactionsModel, child) {
        return ListView.builder(
          itemBuilder: (context, index) {
            if (index.isOdd) {
              return Divider();
            }

            final int i = index ~/ 2;
            if (i >= accounts.length) {
              return null;
            }

            final account = accounts[i];
            final List<Transaction> transactions = [];
            for (var key
                in transactionsModel.transactionsByAccountFullName.keys) {
              if (key.startsWith(account.fullName)) {
                transactions.addAll(
                    transactionsModel.transactionsByAccountFullName[key]!);
              }
            }
            final double balance = transactions.fold(0.0,
                (previousValue, element) => previousValue + element.amount);
            final simpleCurrencyValue = simpleCurrencyNumberFormat.format(balance);

            return ListTile(
              title: Text(
                account.name,
                style: Constants.biggerFont,
              ),
              trailing: Text(
                simpleCurrencyValue
              ),
              onTap: () {
                if (account.children.isEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) {
                      return Scaffold(
                        appBar: AppBar(
                          backgroundColor: Constants.darkBG,
                          title: Text(account.fullName),
                        ),
                        body: TransactionsView(
                            transactions: Provider.of<TransactionsModel>(
                                            context,
                                            listen: true)
                                        .transactionsByAccountFullName[
                                    account.fullName] ??
                                []),
                        floatingActionButton: Builder(builder: (context) {
                          return FloatingActionButton(
                            backgroundColor: Constants.darkBG,
                            child: Icon(Icons.add),
                            onPressed: () async {
                              final success = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TransactionForm(
                                    toAccount: account,
                                  ),
                                ),
                              );

                              if (success != null && success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text("Transaction created!")));
                              }
                            },
                          );
                        }),
                      );
                    }),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AccountView(account: account),
                    ),
                  );
                }
              },
            );
          },
          padding: EdgeInsets.all(16.0),
          shrinkWrap: true,
        );
      }),
    );
  }
}
