import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/utils/formatting.dart';

void main() {
  group('rupees', () {
    test('groups in the Indian convention, not the western one', () {
      expect(rupees(0), '₹0');
      expect(rupees(700), '₹700');
      expect(rupees(1500), '₹1,500');
      expect(rupees(9230), '₹9,230');
      expect(rupees(100000), '₹1,00,000');
      expect(rupees(1500000), '₹15,00,000');
      expect(rupees(12345678), '₹1,23,45,678');
    });

    test('shows paise only when there are any', () {
      expect(rupees(500), '₹500');
      expect(rupees(500.5), '₹500.50');
      expect(rupees(1234.75), '₹1,234.75');
    });

    test('keeps a negative readable', () {
      expect(rupees(-1500), '-₹1,500');
    });
  });

  group('price labels', () {
    test('attach the unit the service is sold in', () {
      expect(priceLabel(250, PriceType.hourly), '₹250/hr');
      expect(priceLabel(2500, PriceType.daily), '₹2,500/day');
      expect(priceLabel(700, PriceType.fixed), '₹700');
      expect(priceLabel(500, PriceType.perPerson), '₹500 per person');
    });

    test(
      'per person shows its working, because the headcount is the negotiation',
      () {
        expect(perPersonTotalLabel(500, 20), '20 × ₹500 = ₹10,000');
        expect(perPersonTotalLabel(500, 18), '18 × ₹500 = ₹9,000');
      },
    );

    test('only per person is priced by headcount', () {
      expect(isPerPersonPrice(PriceType.perPerson), isTrue);
      expect(isPerPersonPrice(PriceType.fixed), isFalse);
      // Orders placed before the server recorded a price type carry null.
      expect(isPerPersonPrice(null), isFalse);
    });

    test('the rate field names the unit being entered', () {
      expect(rateFieldLabel(PriceType.perPerson), 'Rate per person (INR)');
      expect(rateFieldLabel(PriceType.hourly), 'Rate per hour (INR)');
      expect(rateFieldLabel(PriceType.fixed), 'Price (INR)');
    });

    test(
      'per person is priced by headcount, not time, so its duration is plain minutes',
      () {
        expect(durationFieldLabel(PriceType.perPerson), 'Duration (mins)');
      },
    );
  });

  group('durations', () {
    test('read naturally either side of an hour', () {
      expect(formatDuration(20), '20 min');
      expect(formatDuration(60), '1 hr');
      expect(formatDuration(90), '1 hr 30 min');
      expect(formatHoursElapsed(19.1), '19 hrs');
      expect(formatHoursElapsed(72), '3 days');
    });
  });

  group('dates', () {
    // The server sends UTC. A business screen that printed it as it came showed a job at 10:00
    // that the customer saw at 15:30. Written against the machine's own zone, so it holds anywhere.
    final fromServer = DateTime.utc(2026, 10, 30, 10, 0);
    final local = fromServer.toLocal();

    test('a time from the server is shown in local time, on every screen', () {
      expect(formatTime(fromServer), formatTime(local));
      expect(
        formatTime(fromServer),
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
      );
    });

    test('so is the day it falls on', () {
      expect(formatDate(fromServer), formatDate(local));
      expect(formatDayMonth(fromServer), formatDayMonth(local));
    });

    test('a date that is already local is left as it is', () {
      expect(formatDate(DateTime(2026, 9, 14)), '14 Sep 2026');
      expect(formatTime(DateTime(2026, 9, 14, 9, 5)), '09:05');
    });
  });
}
