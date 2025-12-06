import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:version/version.dart';

class UpdateService {
  static const String _owner = 'rubbish-picker';
  static const String _repo = 'manosaba-utils';

  Future<void> checkForUpdates(BuildContext context) async {
    try {
      // 1. Get current app version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      Version currentVersion = Version.parse(packageInfo.version);

      // 2. Fetch latest release from GitHub
      final response = await http.get(
        Uri.parse(
            'https://api.github.com/repos/$_owner/$_repo/releases/latest'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> releaseData = json.decode(response.body);
        String tagName = releaseData['tag_name'];

        // Remove 'v' prefix if present
        if (tagName.startsWith('v')) {
          tagName = tagName.substring(1);
        }

        Version latestVersion = Version.parse(tagName);

        // 3. Compare versions
        if (latestVersion > currentVersion) {
          if (context.mounted) {
            _showUpdateDialog(context, releaseData);
          }
        }
      } else {
        debugPrint('Failed to fetch updates: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  void _showUpdateDialog(
      BuildContext context, Map<String, dynamic> releaseData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('New Update Available'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Version: ${releaseData['tag_name']}'),
                const SizedBox(height: 8),
                const Text('Downloading the latest version from GitHub. A proxy may be required in some regions.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Later'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Update'),
              onPressed: () {
                Navigator.of(context).pop();
                _downloadAndInstall(context, releaseData);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadAndInstall(
      BuildContext context, Map<String, dynamic> releaseData) async {
    // Find APK asset
    final List<dynamic> assets = releaseData['assets'];
    final Map<String, dynamic>? apkAsset = assets.firstWhere(
      (asset) => asset['name'].toString().endsWith('.apk'),
      orElse: () => null,
    );

    if (apkAsset == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No APK found in this release.')),
        );
      }
      return;
    }

    final String downloadUrl = apkAsset['browser_download_url'];
    final String fileName = apkAsset['name'];

    if (!context.mounted) return;

    // Show download dialog and wait for result (file path)
    final String? savePath = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return DownloadDialog(url: downloadUrl, fileName: fileName);
      },
    );

    if (savePath != null) {
      await _installApk(savePath);
    }
  }

  Future<void> _installApk(String filePath) async {
    if (Platform.isAndroid) {
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        debugPrint('Install failed: ${result.message}');
      }
    }
  }
}

class DownloadDialog extends StatefulWidget {
  final String url;
  final String fileName;

  const DownloadDialog({super.key, required this.url, required this.fileName});

  @override
  State<DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<DownloadDialog> {
  double _progress = 0.0;
  final http.Client _client = http.Client();
  bool _isDownloading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String savePath = '${tempDir.path}/${widget.fileName}';

      final request = http.Request('GET', Uri.parse(widget.url));
      final http.StreamedResponse response = await _client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to download: ${response.statusCode}');
      }

      final int totalLength = response.contentLength ?? 0;
      int received = 0;
      final File file = File(savePath);
      final IOSink sink = file.openWrite();

      response.stream.listen(
        (List<int> chunk) {
          received += chunk.length;
          sink.add(chunk);
          if (totalLength > 0) {
            setState(() {
              _progress = received / totalLength;
            });
          }
        },
        onDone: () async {
          await sink.flush();
          await sink.close();
          if (mounted) {
            Navigator.of(context).pop(savePath);
          }
        },
        onError: (e) async {
          await sink.close();
          if (mounted) {
            setState(() {
              _errorMessage = e.toString();
              _isDownloading = false;
            });
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isDownloading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        title: const Text('Downloading Update'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_errorMessage != null)
              Text('Error: $_errorMessage',
                  style: const TextStyle(color: Colors.red))
            else ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 10),
              Text('${(_progress * 100).toStringAsFixed(1)}%'),
            ],
          ],
        ),
        actions: [
          TextButton(
            child: Text(_isDownloading ? 'Cancel' : 'Close'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
