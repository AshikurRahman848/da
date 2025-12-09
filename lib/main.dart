import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:intl/intl.dart';

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

  Future<void> _showDatePicker(String inputId) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.deepPurple,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && _controller != null) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      final displayDate = DateFormat('dd/MM/yyyy').format(picked);
      
      await _controller!.evaluateJavascript(source: '''
        (function() {
          var input = document.getElementById('$inputId');
          if (input) {
            input.value = '$displayDate';
            input.setAttribute('data-value', '$formattedDate');
            
            // Trigger change events
            var event = new Event('input', { bubbles: true });
            input.dispatchEvent(event);
            event = new Event('change', { bubbles: true });
            input.dispatchEvent(event);
            
            console.log('Date set: $displayDate');
          }
        })();
      ''');
    }
  }

  Future<void> _showTimePicker(String inputId) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.deepPurple,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && _controller != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      final timeString = '$hour:$minute';
      
      // Format for display (12-hour format)
      final displayTime = picked.format(context);
      
      await _controller!.evaluateJavascript(source: '''
        (function() {
          var input = document.getElementById('$inputId');
          if (input) {
            input.value = '$displayTime';
            input.setAttribute('data-value', '$timeString');
            
            // Trigger change events
            var event = new Event('input', { bubbles: true });
            input.dispatchEvent(event);
            event = new Event('change', { bubbles: true });
            input.dispatchEvent(event);
            
            console.log('Time set: $displayTime');
          }
        })();
      ''');
    }
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
            
            // Add JavaScript handler for date/time picker
            controller.addJavaScriptHandler(
              handlerName: 'flutterDatePicker',
              callback: (args) async {
                if (args.isNotEmpty) {
                  final data = args[0] as Map<dynamic, dynamic>;
                  final inputId = data['id'] as String;
                  final inputType = data['type'] as String;
                  
                  print('📅 Opening picker for: $inputType (ID: $inputId)');
                  
                  if (inputType == 'date' || inputType == 'datetime-local') {
                    await _showDatePicker(inputId);
                  } else if (inputType == 'time') {
                    await _showTimePicker(inputId);
                  }
                }
              },
            );
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

            // Inject JavaScript to intercept date/time inputs
            try {
              await controller.evaluateJavascript(source: '''
                (function() {
                  var idCounter = 0;
                  
                  function setupDateTimePicker() {
                    var dateInputs = document.querySelectorAll('input[type="date"], input[type="datetime-local"], input[type="time"]');
                    
                    dateInputs.forEach(function(input) {
                      // Skip if already processed
                      if (input.hasAttribute('data-flutter-processed')) {
                        return;
                      }
                      
                      var originalType = input.type;
                      
                      // Assign unique ID if not present
                      if (!input.id) {
                        input.id = 'date_input_' + (idCounter++);
                      }
                      
                      // Store original type
                      input.setAttribute('data-original-type', originalType);
                      input.setAttribute('data-flutter-processed', 'true');
                      
                      // Convert to text to prevent native picker
                      input.type = 'text';
                      input.readOnly = true;
                      input.style.cursor = 'pointer';
                      
                      // Set placeholder
                      if (originalType === 'date' || originalType === 'datetime-local') {
                        input.placeholder = input.placeholder || 'Select date';
                      } else if (originalType === 'time') {
                        input.placeholder = input.placeholder || 'Pick a time';
                      }
                      
                      // Add click listener
                      input.addEventListener('click', function(e) {
                        e.preventDefault();
                        window.flutter_inappwebview.callHandler('flutterDatePicker', {
                          id: input.id,
                          type: originalType
                        });
                      });
                      
                      // Also handle focus event
                      input.addEventListener('focus', function(e) {
                        e.preventDefault();
                        input.blur(); // Remove focus
                        window.flutter_inappwebview.callHandler('flutterDatePicker', {
                          id: input.id,
                          type: originalType
                        });
                      });
                      
                      console.log('✅ Setup Flutter picker for: ' + input.id + ' (type: ' + originalType + ')');
                    });
                  }
                  
                  // Run on load
                  setupDateTimePicker();
                  
                  // Watch for dynamically added inputs
                  var observer = new MutationObserver(function(mutations) {
                    setupDateTimePicker();
                  });
                  
                  observer.observe(document.body, {
                    childList: true,
                    subtree: true
                  });
                  
                  // Error handler
                  window.onerror = function(msg, src, line) {
                    console.log("JS Error: " + msg);
                    return true;
                  };
                  
                  console.log('📱 Flutter date/time picker bridge loaded');
                })();
              ''');
              print('✅ Date picker bridge injected');
            } catch (e) {
              print('❌ JS injection failed: $e');
            }
          },
          onLoadError: (controller, url, code, message) {
            setState(() {
              isLoading = false;
              errorMessage = '$message\n(Error Code: $code)';
            });

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