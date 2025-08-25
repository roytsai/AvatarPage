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
import 'package:flutter_linux_webview/flutter_linux_webview.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

    // 每次都刪掉舊的資料夾
    if (webDir.existsSync()) {
      webDir.deleteSync(recursive: true);
    }

    // 建立新資料夾
    webDir.createSync(recursive: true);

    // 複製 assets
    await _copyAssetFolder('packages/avatar_page/assets/web', webDir.path);

    print('webDir.path: ${webDir.path}');
    final handler = createStaticHandler(webDir.path, defaultDocument: 'index.html');
    _server = await shelf_io.serve(handler, '127.0.0.1', 5763);
    setState(() {
      _localUrl = 'http://127.0.0.1:5763/index.html';
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
