import 'package:flutter_test/flutter_test.dart';
import 'package:flutterwave_standard/flutterwave.dart';

main() {
  group("Customer object", () {
    test("should initialize correctly when values are set", () {
      final email = "testEmail";
      final phoneNumber = "123456789";
      final name = "Random Name";
      final customer = Customer(email: email, name: name, phoneNumber: phoneNumber);

      expect(email, customer.email);
      expect(phoneNumber, customer.phoneNumber);
      expect(name, customer.name);

      final customerHashmap = {
        "email": email,
        "phonenumber": phoneNumber,
        "name": name
      };
      expect(customerHashmap.toString(), customer.toJson().toString());

    });

    test("should initialize correctly when required value is set", () {
      final email = "testEmail";
      final customer = Customer(email: email);

      expect(email, customer.email);
      expect(true, customer.phoneNumber == null);
      expect(true, customer.name == null);

      final customerHashmap = { "email": email };
      expect(customerHashmap.toString(), customer.toJson().toString());
    });

  });
}