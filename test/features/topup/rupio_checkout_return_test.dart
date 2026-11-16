import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:vpay_mobile/features/topup/screens/rupio_checkout_screen.dart';
import 'package:vpay_mobile/features/topup/services/topup_service.dart';

class FakeWebView extends WebViewPlatform {
  late FakeController controller;
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller = FakeController(params);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => FakeDelegate(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) => FakeWidget(params);
}

class FakeController extends PlatformWebViewController {
  FakeController(super.params) : super.implementation();
  late JavaScriptChannelParams channel;
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channel = params;
  }

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
  @override
  Future<void> loadRequest(LoadRequestParams params) async {}
}

class FakeDelegate extends PlatformNavigationDelegate {
  FakeDelegate(super.params) : super.implementation();
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {}
  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async {}
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async {}
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async {}
}

class FakeWidget extends PlatformWebViewWidget {
  FakeWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const Text('Rupio result page');
}

class FakeService implements TopUpService {
  TopUp result = const TopUp(
    id: 'test',
    status: 'SUCCESS',
    requestedAmount: 1,
    amount: 1,
  );
  @override
  Future<TopUp> get(String id) async => result;
  @override
  Future<TopUp> create(int amount) => throw UnimplementedError();
  @override
  Future<List<TopUp>> list() => throw UnimplementedError();
}

void main() {
  testWidgets(
    'verified result stays open until Rupio return button is clicked',
    (tester) async {
      final platform = FakeWebView();
      WebViewPlatform.instance = platform;
      final service = FakeService();
      TopUp? returned;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  returned = await Navigator.of(context).push<TopUp>(
                    MaterialPageRoute(
                      builder: (_) => RupioCheckoutScreen(
                        url: Uri.parse('https://rupio.example/checkout'),
                        topUpId: 'test',
                        service: service,
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(find.text('Rupio result page'), findsOneWidget);
      expect(returned, isNull);
      platform.controller.channel.onMessageReceived(
        const JavaScriptMessage(message: 'return-home'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(returned?.status, 'SUCCESS');
    },
  );

  testWidgets('return click waits for backend confirmation', (tester) async {
    final platform = FakeWebView();
    WebViewPlatform.instance = platform;
    final service = FakeService()
      ..result = const TopUp(id: 'test', status: 'PENDING', requestedAmount: 1);
    TopUp? returned;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                returned = await Navigator.of(context).push<TopUp>(
                  MaterialPageRoute(
                    builder: (_) => RupioCheckoutScreen(
                      url: Uri.parse('https://rupio.example/checkout'),
                      topUpId: 'test',
                      service: service,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    platform.controller.channel.onMessageReceived(
      const JavaScriptMessage(message: 'return-home'),
    );
    await tester.pump();
    expect(find.text('Rupio result page'), findsOneWidget);
    expect(returned, isNull);
    service.result = const TopUp(
      id: 'test',
      status: 'SUCCESS',
      requestedAmount: 1,
      amount: 1,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(returned?.status, 'SUCCESS');
  });
}
