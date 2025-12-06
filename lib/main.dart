import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
      child: Scaffold(
        backgroundColor: Colors.white,

        // ❌ REMOVE extendBodyBehindAppBar
        // extendBodyBehindAppBar: true,

        body: SafeArea(
          top: true,
          bottom: true,
          child: PortalWebView(url: AppConfig.portalUrl),
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
  late final WebViewController _controller;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    print('🌐 Loading URL: ${widget.url}');
    print('🔧 Release Mode: $kReleaseMode');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Mobile Safari/537.36')
      ..enableZoom(true)
      ..setOnConsoleMessage((msg) {
        print("🔴 JS Console: ${msg.message}");
      })
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              isLoading = true;
              errorMessage = null;
            });
          },
          onPageFinished: (url) async {
            setState(() {
              isLoading = false;
            });

            // JS error capture
            try {
              await _controller.runJavaScript('''
                window.onerror = function(msg, src, line) {
                  console.log("JS Error: " + msg);
                  return true;
                };
              ''');
            } catch (e) {
              print('❌ JS injection failed: $e');
            }
          },
          onWebResourceError: (error) {
            setState(() {
              isLoading = false;
              errorMessage =
                  '${error.description}\n(Error Code: ${error.errorCode})';
            });
          },
          onNavigationRequest: (req) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),

        if (isLoading)
          const Center(child: CircularProgressIndicator()),

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
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      setState(() {
                        errorMessage = null;
                        isLoading = true;
                      });
                      _controller.loadRequest(Uri.parse(widget.url));
                    },
                    child: const Text('Retry'),
                  )
                ],
              ),
            ),
          ),
      ],
    );
  }
}
