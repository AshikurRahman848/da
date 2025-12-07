import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MyApp());
}

class AppConfig {
  static const String productionUrl =
      'http://194.233.69.19:5088/da/portal?&id=650217&site=APP';
  static const String developmentUrl =
      'http://194.233.69.19:5088/da/portal?&id=650217&site=APP';

  static String get portalUrl {
    return kReleaseMode ? productionUrl : developmentUrl;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'DA'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: PortalWebView(url: AppConfig.portalUrl),
          ),
        ),
      ),
    );
  }
}

class PortalWebView extends StatefulWidget {
  final String url;
  const PortalWebView({Key? key, required this.url}) : super(key: key);

  @override
  State<PortalWebView> createState() => _PortalWebViewState();
}

class _PortalWebViewState extends State<PortalWebView> {
  InAppWebViewController? _controller;
  bool isLoading = true;
  String? errorMessage;
  int _retryAttempts = 0;
  final int _maxRetries = 3;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    print('🌐 Loading URL: ${widget.url}');
    print('🔧 Release Mode: $kReleaseMode');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.url)),
          initialOptions: InAppWebViewGroupOptions(
            crossPlatform: InAppWebViewOptions(
              javaScriptEnabled: true,
              useOnDownloadStart: true,
              mediaPlaybackRequiresUserGesture: false,
            ),
            android: AndroidInAppWebViewOptions(
              useHybridComposition: true,
            ),
          ),
          onWebViewCreated: (controller) {
            _controller = controller;
          },
          onConsoleMessage: (controller, consoleMessage) {
            print('🔴 JS Console [${consoleMessage.messageLevel}]: ${consoleMessage.message}');
          },
          onLoadStart: (controller, url) {
            setState(() {
              isLoading = true;
              errorMessage = null;
            });
          },
          onLoadStop: (controller, url) async {
            setState(() {
              isLoading = false;
            });

            // JS error capture
            try {
              await controller.evaluateJavascript(source: '''
                window.onerror = function(msg, src, line) {
                  console.log("JS Error: " + msg);
                  return true;
                };
              ''');
            } catch (e) {
              print('❌ JS injection failed: $e');
            }
          },
          onLoadError: (controller, url, code, message) {
            setState(() {
              isLoading = false;
              errorMessage = '$message\n(Error Code: $code)';
            });

            // Schedule automatic retry with exponential backoff
            if (_retryAttempts < _maxRetries) {
              _retryAttempts += 1;
              final delay = Duration(seconds: 2 * _retryAttempts);
              print('⏱️ Scheduling retry #${_retryAttempts} in ${delay.inSeconds}s');
              _retryTimer?.cancel();
              _retryTimer = Timer(delay, () {
                if (!mounted) return;
                setState(() {
                  errorMessage = null;
                  isLoading = true;
                });
                _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(widget.url)));
              });
            } else {
              print('⚠️ Max retry attempts reached ($_maxRetries)');
            }
          },
          onDownloadStartRequest: (controller, download) {
            // Optional: handle downloads separately if needed
            print('📥 Download requested: ${download.url}');
          },
        ),

        if (isLoading) const Center(child: CircularProgressIndicator()),

        if (errorMessage != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load portal',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Manual retry: cancel any scheduled retries and reload now
                      _retryTimer?.cancel();
                      _retryAttempts = 0;
                      setState(() {
                        errorMessage = null;
                        isLoading = true;
                      });
                      _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(widget.url)));
                    },
                    style: ElevatedButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                    ),
                    child: const Icon(Icons.refresh),
                  )
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}
