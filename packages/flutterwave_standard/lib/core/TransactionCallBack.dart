import 'package:flutterwave_standard/flutterwave.dart';

abstract class TransactionCallBack {
  onTransactionComplete(ChargeResponse? chargeResponse);
}