import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:resumable_upload/resumable_upload.dart';

import 'package:connectivity_plus/connectivity_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resumable upload Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Resumable upload Demo Home Page'),
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
  String process = '0%';
  String exception = '';
  late UploadClient? client;
  final LocalCache _localCache = LocalCache();

  bool shouldRetry = false;
  var isConnected = false;
  late bool isInternetConnected;
  late StreamSubscription<ConnectivityResult> subscription;
  String? localFilepath = '';
  bool initial = false;
  late File file;
  late String finalpath;
  String sasToken =
      'si=policy&spr=https&sv=2022-11-02&sr=c&sig=jQn5MRzc3xZU4HO5sv2pNUyPAkswfqYFHXI5kq%2BulLA%3D';
  @override
  void initState() {
    init();
    super.initState();
  }

  init() async {
    return this;
  }

  Future<bool> checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      } else {
        return false;
      }
    } on SocketException catch (_) {
      return false;
    }
  }

  listen() {
    subscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      Future.delayed(const Duration(seconds: 1), () async {
        if (result != ConnectivityResult.none) {
          isInternetConnected = await checkInternetConnection();
        } else {
          isInternetConnected = false;
        }
        if (isInternetConnected != isConnected) {
          setState(() {
            isConnected = isInternetConnected;
          });
          if (isConnected && shouldRetry && initial) {
            _upload_func(retryCount: 0);
            shouldRetry = false;
          }
        }
      });
    });
  }

  Future<void> handleUploadFailure(int retryCount) async {
    try {
      if (retryCount > 3) {
        return;
      } else if (!isConnected) {
        shouldRetry = true;
      } else if (isConnected) {
        Future.delayed(const Duration(seconds: 3), () {
          _upload_func(retryCount: retryCount + 1);
        });
      }
    } catch (e) {
      shouldRetry = true;
      print(e);
      setState(() {
        exception = e.toString();
      });
    }
  }

  _upload_func({retryCount = 0}) async {
    listen();
    if (retryCount == 0 && !shouldRetry) {
      localFilepath = await filePathPicker();
      file = File(localFilepath!);
      String dateString =
          '${DateTime.now().millisecondsSinceEpoch}.${file.path.split('.').last}';
      const String blobUrl =
          'https://worksamplestorageaccount.blob.core.windows.net/blob-video';

      finalpath = '$blobUrl/$dateString';
      shouldRetry = isConnected ? false : true;
      initial = true;
    }
    try {
      client = UploadClient(
        file: file,
        cache: _localCache,
        blobConfig: BlobConfig(blobUrl: finalpath, sasToken: sasToken),
      );
      client!.uploadBlob(
        onProgress: (count, total, response) {
          final num = ((count / total) * 100).toInt().toString();
          setState(() {
            process = '$num%';
          });
          shouldRetry = true;
        },
        onComplete: (path, response) {
          setState(() {
            process = 'Completed';
          });
          shouldRetry = false;
          subscription.cancel();
        },
        onFailed: (e) {
          setState(() {
            process = e;
          });
        },
      );
    } catch (e) {
      handleUploadFailure(retryCount);
      shouldRetry = true;
      setState(() {
        exception = e.toString();
      });
    }
  }

  Future<String?> filePathPicker() async {
    File? file;

    try {
      final XFile? galleryFile = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
      );

      if (galleryFile == null) {
        return null;
      }

      file = File(galleryFile.path);
    } catch (e) {
      return null;
    }

    return file.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              process,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(
              height: 20.0,
            ),
            Text(exception),
            const SizedBox(
              height: 20.0,
            ),
            isConnected
                ? const Text("Internet Connected")
                : const Text("Wating for network"),
            const SizedBox(
              height: 20.0,
            ),
            InkWell(
              onTap: () {
                setState(() {
                  process = 'Cancelled';
                });
                client!.cancelClient();
              },
              child: Container(
                color: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32.0, vertical: 16.0),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _upload_func,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
