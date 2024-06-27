import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wayfinderai/loader.dart';
import 'package:wayfinderai/tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

const String apiKey = String.fromEnvironment('API_KEY');
Future<void> main() async {


  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wayfinder AI',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
        useMaterial3: true,
      ),
      home:  const splash_screen(),debugShowCheckedModeBanner: false,
      //const MyHomePage(title: 'Wayfinder AI'),
    );
  }
}
enum TtsState { playing, stopped, paused, continued }
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  /////////tts
  late FlutterTts flutterTts;
  // String? language;
  // String? engine;
  // double volume = 0.5;
  // double pitch = 1.0;
  // double rate = 0.5;
  bool isCurrentLanguageInstalled = false;

  String? _newVoiceText;
  int? _inputLength;

  TtsState ttsState = TtsState.stopped;

  bool get isPlaying => ttsState == TtsState.playing;
  bool get isStopped => ttsState == TtsState.stopped;
  bool get isPaused => ttsState == TtsState.paused;
  bool get isContinued => ttsState == TtsState.continued;

  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get isWindows => !kIsWeb && Platform.isWindows;
  bool get isWeb => kIsWeb;
  /////////tts
  int _counter = 0;
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  Uint8List? _currentFrame;
  bool _isProcessing = false;




  // final model = GenerativeModel(model: 'gemini-1.5-pro', apiKey: apiKey);
 // tts ttsval = tts();
  @override
  void initState() {
    super.initState();
    _initializeCamera();
    initTts();

  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _controller = CameraController(_cameras![0], ResolutionPreset.low);
      await _controller!.initialize();
      await _controller!.lockCaptureOrientation();
      await _controller!.startImageStream(_processCameraImage);
      setState(() {
        _isCameraInitialized = true;
      });
    }
  }



  Uint8List _convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;

    final img.Image yuvImage = img.Image(height, width);

    for (int y = 0; y < height; y++) {
      int uvIndex = uvRowStride * (y >> 1);
      for (int x = 0; x < width; x++) {
        final int uvOffset = uvIndex + (x >> 1) * uvPixelStride;
        final int yValue = image.planes[0].bytes[y * width + x];
        final int uValue = image.planes[1].bytes[uvOffset];
        final int vValue = image.planes[2].bytes[uvOffset];

        final r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
        final g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).clamp(0, 255).toInt();
        final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

        yuvImage.setPixel(x, y, img.getColor(r, g, b));
      }
    }

    return Uint8List.fromList(img.encodeJpg(yuvImage));
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;

    _isProcessing = true;

    try {

      final bytes = _convertYUV420ToImage(image);
      final safetySettings = [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
      ];

      final model = GenerativeModel(
        model: 'gemini-1.5-flash-latest',
        apiKey: apiKey,
        safetySettings: safetySettings,
      );

      final content = [
        Content.multi([
          TextPart('What do you see? image as instruction blind person to show direction.tell if doors,windows,hallways,street signs,landmarks or any other obstacles in the path.also if there are signs like male female toilets,no entry,etc tell it also. No extra words, only where is the path and in which side and give only like person is speaking not reading tense'),
          DataPart('image/jpeg',bytes  ),
        ])
      ];

      var response = await model.generateContent(content);
      var text = response.text;
      _newVoiceText = response.text;
      _isProcessing = false;
      print(text);
_speak();
      setState(() {
        _currentFrame = bytes;
      });
    } catch (e) {
      print('Error processing image: $e');
      _isProcessing = false;
    } finally {

    }
  }



  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
    flutterTts.stop();
  }
  ////////tts
  dynamic initTts() async {
    flutterTts = FlutterTts();

    _setAwaitOptions();

    if (isAndroid) {
      _getDefaultEngine();
      _getDefaultVoice();
    }

    flutterTts.setStartHandler(() {
      setState(() {
        print("Playing");
        ttsState = TtsState.playing;
      });
    });

    flutterTts.setCompletionHandler(() {
      setState(() {
        print("Complete");
        ttsState = TtsState.stopped;
      });
    });

    flutterTts.setCancelHandler(() {
      setState(() {
        print("Cancel");
        ttsState = TtsState.stopped;
      });
    });

    flutterTts.setPauseHandler(() {
      setState(() {
        print("Paused");
        ttsState = TtsState.paused;
      });
    });

    flutterTts.setContinueHandler(() {
      setState(() {
        print("Continued");
        ttsState = TtsState.continued;
      });
    });

    flutterTts.setErrorHandler((msg) {
      setState(() {
        print("error: $msg");
        ttsState = TtsState.stopped;
      });
    });
_newVoiceText="Welcome to way finder AI. powered by gemini AI. I will guid you to find your way!";
    _isProcessing = true;
   await _speak();
    _isProcessing = false;

  }



  Future<void> _getDefaultEngine() async {

    var engine = await flutterTts.getDefaultEngine;
    if (engine != null) {
      print(engine);
    }
  }

  Future<void> _getDefaultVoice() async {
    var voice = await flutterTts.getDefaultVoice;
    if (voice != null) {
      print(voice);
    }
  }

  Future<void> _speak() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final double? volume = prefs.getDouble('volume');
    final double? rate = prefs.getDouble('rate');
    final double? pitch = prefs.getDouble('pitch');
    final String? language = prefs.getString('language');





if(language!=null){
  await  flutterTts.setLanguage(language!);
}
    if(volume!=null){
      await flutterTts.setVolume(volume!);
    }
    else{
      await flutterTts.setVolume(0.5);
    }
    if(rate!=null){
      await flutterTts.setSpeechRate(rate!);
    }
    else{
      await flutterTts.setSpeechRate(0.5);
    }
    if(pitch!=null){
      await flutterTts.setPitch(pitch!);
    }
    else{
      await flutterTts.setPitch(1);
    }



    if (_newVoiceText != null) {
      if (_newVoiceText!.isNotEmpty) {
        await flutterTts.speak(_newVoiceText!);
      }
    }
  }

  Future<void> _setAwaitOptions() async {
    await flutterTts.awaitSpeakCompletion(true);
  }

  Future<void> _stop() async {
    var result = await flutterTts.stop();
    if (result == 1) setState(() => ttsState = TtsState.stopped);
  }

  Future<void> _pause() async {
    var result = await flutterTts.pause();
    if (result == 1) setState(() => ttsState = TtsState.paused);
  }

  ////////tts



  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: _isCameraInitialized
          ? Stack(
        children: [
          AspectRatio(
            aspectRatio: 09.0/16.0,
            child: CameraPreview(_controller!),
          ),

          const Positioned.fill(child: Center(child: loader())),


          // if (_currentFrame != null)
          //   Positioned(
          //     bottom: 20,
          //     left: 20,
          //     child: Container(
          //       color: Colors.white,
          //       child: Text(
          //         'Frame size: ${_currentFrame!.lengthInBytes} bytes',
          //         style: TextStyle(color: Colors.black),
          //       ),
          //     ),
          //   ),
        ],
      )
          : Center(
        child: CircularProgressIndicator(),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blueGrey,image:DecorationImage(
                fit: BoxFit.cover,
                // colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.2), BlendMode.dstATop),
                image: AssetImage("assets/logo.png"),scale: 0.1,

                // image: Image.asset('assets/images/pikachu.png').image,
              ),
              ),
              child:
              Text(
                '',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => tts()),
                );
              },
            ),



            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '© 2024 Wayfinder AI',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),

          ],
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     Navigator.push(
      //         context,
      //         MaterialPageRoute(builder: (context) => tts())
      //     );
      //   },
      //   tooltip: 'Increment',
      //   child: const Icon(Icons.settings),
      // ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
class splash_screen extends StatefulWidget {
  static const String id = 'splash_screen';
  const splash_screen({Key? key}) : super(key: key);
  @override
  SplashState createState() => SplashState();
}

class SplashState extends State<splash_screen> {

  @override
  void initState() {
    // TODO: implement initState

    super.initState();

    startTime();

  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: initScreen(context),
    );
  }
  Future<void> checkIfUserExists() async {

    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => MyHomePage(title: 'Wayfinder AI',)));

  }
  startTime() async {
    var duration = new Duration(seconds: 6);
    return new Timer(duration, checkIfUserExists);
  }



  initScreen(BuildContext context) {
    return Scaffold(
      body:

      Container(
        decoration: BoxDecoration(
          //color: Colors.pinkAccent,
          image: DecorationImage(
            fit: BoxFit.cover,
            // colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.2), BlendMode.dstATop),
            image: AssetImage("assets/sc1.png"),

            // image: Image.asset('assets/images/pikachu.png').image,
          ),
        ),


        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Container(
            //   child: Image.asset("assets/logo2.jpg"),
            // ),
            Padding(padding: EdgeInsets.only(top: 450.0)),
            // Text(
            //   "Officers' Mess Management System",textAlign: TextAlign.center,
            //   style: TextStyle(fontSize: 30.0, color: Colors.black),
            // ),
            //Padding(padding: EdgeInsets.only(top: 20.0)),
            // Text(
            //   "Dte of IT @2024",textAlign: TextAlign.center,
            //   style: TextStyle(fontSize: 18.0, color: Colors.white),
            // ),
            // CircularProgressIndicator(
            //   backgroundColor: Colors.white,
            //   strokeWidth: 1,
            // )
          ],
        ),
      ),
    );
  }
}