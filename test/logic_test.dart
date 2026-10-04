import 'package:flutter_test/flutter_test.dart';
import 'package:spectrumwhisper/local_seal.dart';
import 'package:spectrumwhisper/logic/radio_math.dart';
import 'package:spectrumwhisper/models.dart';

void main() {
  final settings = AppSettings.defaults();

  CategoryGuess guess(Map<String, Object?> extra) {
    return classify(
      ssid: extra['ssid'] as String? ?? 'Unit-4B',
      bssid: extra['bssid'] as String? ?? '00:00:0C:11:22:01',
      hidden: extra['hidden'] as bool? ?? false,
      overrideCategory: extra['override'] as String? ?? '',
      autoClassify: true,
      vehiclePatterns: settings.vehiclePatterns,
      printerPatterns: settings.printerPatterns,
      hotspotPatterns: settings.hotspotPatterns,
      routerPatterns: settings.routerPatterns,
    );
  }

  test('names and vendor sort vehicle, hotspot, printer, and unknown', () {
    expect(guess({'ssid': 'Mira iPhone'}).category, 'phone');
    expect(guess({'ssid': 'Mira iPhone'}).tag, 'Apple iPhone');
    expect(guess({'ssid': 'Chevy-WiFi', 'bssid': '02:11:22:33:44:10'}).category, 'vehicle');
    expect(guess({'ssid': 'Chevy-WiFi', 'bssid': '02:11:22:33:44:10'}).tag, 'Chevrolet');
    expect(guess({'ssid': 'Ford F-150', 'bssid': '02:11:22:33:44:10'}).tag, 'Ford F-150');
    expect(guess({'ssid': 'SEAT Leon', 'bssid': '02:11:22:33:44:10'}).tag, 'SEAT');
    expect(guess({'ssid': 'smartphone', 'bssid': '02:11:22:33:44:10'}).category, 'unknown');
    expect(guess({'ssid': 'Yamaha', 'bssid': '02:11:22:33:44:10'}).category, 'unknown');
    expect(guess({'ssid': 'Yamaha R1', 'bssid': '02:11:22:33:44:10'}).tag, 'Yamaha Vehicle');
    expect(guess({'ssid': 'Land Rover', 'bssid': '02:11:22:33:44:10'}).tag, 'Land Rover');
    expect(guess({'ssid': 'NETGEAR-5G'}).tag, 'Netgear');
    expect(guess({'ssid': 'HUAWEI-B310', 'bssid': '02:11:22:33:44:10'}).tag, 'Huawei');
    expect(guess({'ssid': 'Huawei P30', 'bssid': '02:11:22:33:44:10'}).category, 'phone');
    expect(guess({'ssid': 'Xiaomi_A1B2', 'bssid': '02:11:22:33:44:10'}).category, 'router');
    expect(guess({'ssid': 'Xiaomi 13', 'bssid': '02:11:22:33:44:10'}).category, 'phone');
    expect(guess({'ssid': 'Dell WiFi', 'bssid': '02:11:22:33:44:10'}).tag, 'Dell Router');
    expect(guess({'ssid': 'Apple TV', 'bssid': '02:11:22:33:44:10'}).category, 'tv');
    expect(guess({'ssid': 'Airport Express', 'bssid': '02:11:22:33:44:10'}).tag, 'Apple AirPort');
    expect(guess({'ssid': 'Motorola', 'bssid': '02:11:22:33:44:10'}).category, 'phone');
    expect(guess({'ssid': 'Billionaire', 'bssid': '02:11:22:33:44:10'}).category, 'unknown');
    expect(guess({'ssid': 'Fritz!Box', 'bssid': '02:11:22:33:44:10'}).tag, 'AVM Fritz!Box');
    expect(guess({'ssid': 'Oxford Hall'}).category, 'router');
    expect(guess({'ssid': 'Oxford Hall', 'bssid': '02:11:22:33:44:10'}).category, 'unknown');
    expect(guess({'ssid': 'HP LaserJet'}).tag, 'HP LaserJet');
    expect(guess({'ssid': 'Dell Printer', 'bssid': '02:11:22:33:44:10'}).tag, 'Dell Printer');
    expect(guess({'ssid': 'Brother HL-L2350'}).tag, 'Brother');
    expect(guess({'ssid': 'Canon MX490', 'bssid': '02:11:22:33:44:10'}).tag, 'Canon Printer');
    expect(guess({'ssid': 'Canon EOS R5', 'bssid': '02:11:22:33:44:10'}).category, 'camera');
    expect(guess({'ssid': 'Mira iPhone'}).category, 'phone');
    expect(guess({'ssid': 'xfinitywifi'}).category, 'hotspot');
    expect(guess({'ssid': 'WL-4481', 'bssid': '02:AA:BB:CC:DD:10'}).category, 'unknown');
    expect(guess({'ssid': 'Harbor-Office'}).category, 'router');
    expect(guess({'ssid': 'Harbor-Office'}).tag, 'Cisco');
    expect(guess({'ssid': 'Road-44', 'override': 'building'}).category, 'other');
    expect(guess({'ssid': 'Chevrolet', 'bssid': '00:00:0C:11:22:01'}).tag, 'Chevrolet');
    expect(guess({'ssid': 'Chevrolet', 'bssid': '00:00:0C:11:22:01'}).category, 'vehicle');
    expect(guess({'ssid': 'Ford Hotspot', 'bssid': '02:11:22:33:44:10'}).category, 'vehicle');
    expect(guess({'ssid': 'HotspotmT37', 'bssid': '02:11:22:33:44:10'}).tag, 'Vehicle hotspot');
    expect(guess({'ssid': 'PROJmT37', 'bssid': '02:11:22:33:44:10'}).tag, 'Vehicle projection');
    expect(guess({'ssid': 'Android Hotspot', 'bssid': '02:11:22:33:44:10'}).category, 'hotspot');
    expect(guess({'ssid': 'Verizon', 'bssid': '00:00:0C:11:22:01'}).category, 'hotspot');
    expect(guess({'ssid': 'Uconnect', 'bssid': '02:11:22:33:44:10'}).tag, 'Chrysler Uconnect');
    expect(guess({'ssid': 'Stellantis', 'bssid': '02:11:22:33:44:10'}).category, 'vehicle');
    expect(guess({'ssid': 'Blue Link', 'bssid': '02:11:22:33:44:10'}).tag, 'Hyundai');
    expect(guess({'ssid': 'HondaLink', 'bssid': '02:11:22:33:44:10'}).tag, 'Honda');
    expect(guess({'ssid': 'ConnectedDrive', 'bssid': '02:11:22:33:44:10'}).tag, 'BMW');
    expect(guess({'ssid': 'myVW', 'bssid': '02:11:22:33:44:10'}).tag, 'Volkswagen');
    expect(guess({'ssid': 'OnStar', 'bssid': '02:11:22:33:44:10'}).tag, 'OnStar');
    expect(guess({'ssid': 'FordPass Connect', 'bssid': '02:11:22:33:44:10'}).tag, 'Ford');
    expect(guess({'ssid': 'STARLINK', 'bssid': '02:11:22:33:44:10'}).category, 'hotspot');
    expect(guess({'ssid': 'Subaru STARLINK', 'bssid': '02:11:22:33:44:10'}).tag, 'Subaru');
    expect(guess({'ssid': 'Wi-Fi Connect', 'bssid': '02:11:22:33:44:10'}).tag, 'Toyota');
    expect(guess({'ssid': 'Netgear Wi-Fi Connect', 'bssid': '02:11:22:33:44:10'}).tag, 'Netgear');
    expect(guess({'ssid': 'My Truck', 'bssid': '02:11:22:33:44:10'}).category, 'vehicle');
    expect(guess({'ssid': 'Carson', 'bssid': '02:11:22:33:44:10'}).category, 'unknown');
    expect(guess({'ssid': 'project', 'bssid': '02:11:22:33:44:10'}).category, 'unknown');
    expect(guess({'ssid': 'CarPlay', 'bssid': '02:11:22:33:44:10'}).category, 'vehicle');
  });

  test('channel presence separates steady from intermittent', () {
    final steady = List.generate(10, (_) => {'2.4:6', '5:36'});
    final scans = [
      for (var i = 0; i < 10; i++) {...steady[i], if (i < 2) '2.4:11'},
    ];
    final stays = channelStays(
      scans: scans,
      latestDbm: const {'2.4:6': -60, '5:36': -70, '2.4:11': -80},
      latestCounts: const {'2.4:6': 3, '5:36': 1, '2.4:11': 1},
    );
    expect(stays.firstWhere((stay) => stay.channel == 6).pattern, 'Steady');
    expect(stays.firstWhere((stay) => stay.channel == 6).aps, 3);
    expect(stays.firstWhere((stay) => stay.channel == 11).pattern, 'Intermittent');
  });

  test('device line uses the name and the maker', () {
    expect(deviceLine('Mira iPhone', '00:03:93:77:00:11'), 'Apple iPhone · Mobile');
    expect(deviceLine('Harbor-Office', '00:00:0C:11:22:01'), 'Cisco · Router');
    expect(deviceLine('Tesla_ModelY', '02:11:22:33:44:10'), 'Tesla · Vehicle');
    expect(makerOf('B0:95:75:12:00:09'), 'TP-Link');
  });

  test('stronger signal is closer', () {
    final near = estimateMeters(dbm: -50, freqMhz: 5200, txDbm: 18, exponent: 3);
    final far = estimateMeters(dbm: -85, freqMhz: 5200, txDbm: 18, exponent: 3);
    expect(near, lessThan(far));
    expect(signalReach(-30), 0);
    expect(signalReach(-90), 1);
    expect(signalReach(-60), closeTo(0.5, 0.001));
    expect(signalReach(-10), 0);
    expect(signalReach(-120), 1);
    expect(ruleOfThumbLine('40 ft'), contains('40 ft'));
    expect(shownFieldIndexes(10, (index) => index == 9), [0, 1, 2, 3, 4, 5, 6, 7, 9]);
    expect(shownFieldIndexes(10, (index) => index == 2), [0, 1, 2, 3, 4, 5, 6, 7]);
    expect(shownFieldIndexes(3, (_) => true), [0, 1, 2]);
    expect(sharedNameCount(['Harbor', 'harbor', 'Other'], 'Harbor'), 2);
    expect(sharedNameCount([''], ''), 0);
    expect(sharedNameLine(1), isEmpty);
    expect(sharedNameLine(3), '3 radios use this name.');
    expect(cleanWatchNote('  kitchen   radio  '), 'kitchen radio');
    expect(watchNoteFor(bssid: 'aa:bb', ssid: 'Harbor', notes: {watchAddressKey('aa:bb'): 'kitchen'}), 'kitchen');
    expect(
      watchNoteFor(bssid: 'aa:bb', ssid: 'Harbor', notes: {watchAddressKey('aa:bb'): 'kitchen', watchNameKey('Harbor'): 'upstairs'}),
      'kitchen · upstairs',
    );
    final settings = AppSettings.fromJson({
      'pinned': ['aa:bb:cc:dd:ee:ff'],
      'watchNames': ['Harbor'],
      'watchNotes': {
        'mac:AA:BB:CC:DD:EE:FF': 'kitchen',
        'name:harbor': 'upstairs',
        'mac:11:22:33:44:55:66': 'stray',
      },
    });
    expect(settings.watchNotes['mac:AA:BB:CC:DD:EE:FF'], 'kitchen');
    expect(settings.watchNotes['name:harbor'], 'upstairs');
    expect(settings.watchNotes.containsKey('mac:11:22:33:44:55:66'), isFalse);
    expect(bandOf(5180).band, '5');
    expect(bandOf(2437).channel, 6);
    expect(stampIsCurrent(100, 100), isTrue);
    expect(stampIsCurrent(100, 100 + 5000000), isTrue);
    expect(stampIsCurrent(100, 100 + 30000000), isFalse);
    final crowded = {for (var channel = 1; channel <= 13; channel++) '2.4:$channel': 3};
    crowded['2.4:6'] = 1;
    expect(quietest24Channel(crowded), 6);
    final tied = {for (var channel = 1; channel <= 13; channel++) '2.4:$channel': 2};
    tied['2.4:3'] = 0;
    tied['2.4:6'] = 0;
    expect(quietest24Channel(tied), 6);
    expect(quietest24Channel({}), 1);
  });

  test('local catalog text is sealed', () async {
    final key = List<int>.generate(32, (i) => i + 1);
    final seal = LocalSeal(memoryKey: key);
    const secret = '{"ssid":"Harbor-Office","bssid":"00:00:0C:11:22:01"}';
    final stored = await seal.sealText(secret);
    expect(seal.isSealed(stored), isTrue);
    expect(stored.contains('Harbor-Office'), isFalse);
    expect(await seal.openText(stored), secret);
    expect(await seal.openText(secret), secret);
    final other = LocalSeal(memoryKey: List<int>.generate(32, (i) => i + 9));
    expect(other.openText(stored), throwsA(isA<Object>()));
  });
}
