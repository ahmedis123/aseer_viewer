import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'أسير',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2196F3),
          elevation: 0,
        ),
      ),
      home: const MyWebViewPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyWebViewPage extends StatefulWidget {
  const MyWebViewPage({Key? key}) : super(key: key);

  @override
  _MyWebViewPageState createState() => _MyWebViewPageState();
}

class _MyWebViewPageState extends State<MyWebViewPage> {
  late InAppWebViewController _webViewController;
  bool _isConnected = true;
  double _progress = 0;
  DateTime? _lastCheckTime;
  bool? _lastCheckResult;

  static const String _urlString = 'https://aseer.net';

  @override
  void initState() {
    super.initState();
    _updateConnectionStatus();
  }

  Future<bool> _hasInternet() async {
    // استخدام كاش بسيط لمدة 5 ثواني لتقليل الاستدعاءات
    if (_lastCheckTime != null &&
        DateTime.now().difference(_lastCheckTime!).inSeconds < 5 &&
        _lastCheckResult != null) {
      return _lastCheckResult!;
    }
    bool result;
    try {
      final lookup = await InternetAddress.lookup('example.com');
      result = lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } catch (_) {
      result = false;
    }
    _lastCheckTime = DateTime.now();
    _lastCheckResult = result;
    return result;
  }

  Future<void> _updateConnectionStatus() async {
    final connected = await _hasInternet();
    if (mounted) {
      setState(() => _isConnected = connected);
    }
  }

  Future<void> _reloadPage() async {
    final connected = await _hasInternet();
    if (connected) {
      _webViewController.reload();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد اتصال بالإنترنت')),
        );
      }
    }
  }

  Future<void> _confirmExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الإغلاق'),
        content: const Text('هل تريد الخروج من التطبيق؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لا'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم'),
          ),
        ],
      ),
    );
    if (shouldExit == true) {
      SystemNavigator.pop();
    }
  }

  Widget _buildOfflineView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'لا يوجد اتصال بالإنترنت',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                await _updateConnectionStatus();
                if (_isConnected) {
                  _webViewController.reload();
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(_urlString);

    return WillPopScope(
      onWillPop: () async {
        // إذا يمكن الرجوع داخل الويب، نرجع بدل خروج
        if (_isConnected && await _webViewController.canGoBack()) {
          _webViewController.goBack();
          return false;
        } else {
          await _confirmExit();
          return false;
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // الويب فيو أو شاشة عدم الاتصال
            _isConnected && uri != null
                ? InAppWebView(
              initialUrlRequest: URLRequest(url: uri),
              initialOptions: InAppWebViewGroupOptions(
                crossPlatform: InAppWebViewOptions(
                  useShouldOverrideUrlLoading: true,
                  mediaPlaybackRequiresUserGesture: false,
                ),
                android: AndroidInAppWebViewOptions(useHybridComposition: true),
                ios: IOSInAppWebViewOptions(allowsInlineMediaPlayback: true),
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;
              },
              onLoadStart: (_, __) => setState(() => _progress = 0),
              onProgressChanged: (_, p) => setState(() => _progress = p / 100),
              onLoadStop: (_, __) => setState(() => _progress = 1.0),
              onLoadError: (_, __, ___, ____) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('فشل تحميل الصفحة'),
                      action: SnackBarAction(
                        label: 'إعادة المحاولة',
                        onPressed: _reloadPage,
                      ),
                    ),
                  );
                }
              },
            )
                : _buildOfflineView(),

            // مؤشر التحميل في منتصف الشاشة
            if (_isConnected && _progress < 1.0)
              Center(
                child: SizedBox(
                  width: 200,
                  height: 4,
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
