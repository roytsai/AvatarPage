import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'dart:convert';

class AvatarPage extends StatefulWidget {
  const AvatarPage({super.key});

  @override
  _AvatarState createState() => _AvatarState();
}

class _AvatarState extends State<AvatarPage> {
  HttpServer? _server;
  late final WebViewController _controller;
  String _localUrl = '';

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();

    // 初始化 Linux WebView 插件，並禁用 GPU 以避免驅動程式問題
    LinuxWebViewPlugin.initialize(options: {
      'user-agent': 'Flutter Linux WebView',
      'remote-debugging-port': '8888',
      'autoplay-policy': 'no-user-gesture-required',
      'enable-gpu': '',
      'enable-webgl': '',
      'ignore-gpu-blocklist': '',
      'use-gl': 'desktop',
    });

    // 設定 WebView 平台為 Linux
    WebView.platform = LinuxWebView();

    startServer();
  }

  @override
  void dispose() {
    _server?.close(force: true);
    print('Local server stopped.');
    super.dispose();
  }

  Future<void> startServer() async {
    final tempDir = await getTemporaryDirectory();
    final webDir = Directory(p.join(tempDir.path, 'web'));

    final indexFile = File(p.join(webDir.path, 'index.html'));
    print('indexFile.existsSync() = ${indexFile.existsSync()}');
    if (!indexFile.existsSync()) {
      webDir.createSync(recursive: true);
      print('Copying assets to ${webDir.path}');
      await _copyAssetFolder('assets/web', webDir.path);
    }

    final handler = createStaticHandler(webDir.path, defaultDocument: 'index.html');
    _server = await shelf_io.serve(handler, '127.0.0.1', 8080);
    setState(() {
      _localUrl = 'http://127.0.0.1:8080/index.html';
    });

    print('Local server started on $_localUrl');
  }

  Future<void> _copyAssetFolder(String assetPath, String targetPath) async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    print('Manifest keys: ${manifestMap.keys.toList()}');
    for (String key in manifestMap.keys) {
      if (key.startsWith(assetPath)) {
        final data = await rootBundle.load(key);
        final relativePath = key.substring(assetPath.length);
        final cleanPath = relativePath.startsWith('/') ? relativePath.substring(1) : relativePath;
        final file = File(p.join(targetPath, cleanPath));
        file.parent.createSync(recursive: true);
        await file.writeAsBytes(data.buffer.asUint8List());
        print('Copy $key -> ${file.path}');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_server == null || _localUrl.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Local HTML WebView')),
      body: Stack(
        children: [
          WebView(
            initialUrl: _localUrl,
            javascriptMode: JavascriptMode.unrestricted,
            debuggingEnabled: true,
            onWebViewCreated: (WebViewController controller) {
              _controller = controller;
            },
            onPageFinished: (String url) {
              if (url != 'about:blank') {
                print('onPageFinished: $url');
              }
            },
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: ElevatedButton(
              onPressed: () {
                // 這裡可以呼叫 JS
              },
              child: const Text('send text WebView'),
            ),
          ),
        ],
      ),
    );
  }

  void callTtsResult(String text) {
    print('callTtsResult = $text');
    String jsCode = "document.getElementById('avatar').ttsResult = $text;";
    _controller.runJavascript(jsCode);
  }
}
