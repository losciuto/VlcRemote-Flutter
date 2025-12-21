import 'package:flutter_test/flutter_test.dart';

import 'package:vlc_remote_flutter/main.dart';

void main() {
  testWidgets('VLC Remote app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const VlcRemoteApp());

    // Verify that the app title is present
    expect(find.text('VLC Remote'), findsOneWidget);
    
    // Verify that we see the "not connected" message
    expect(find.text('Non connesso a VLC'), findsOneWidget);
  });
}
