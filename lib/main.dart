import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite/tflite.dart';
import 'dart:math' as math;

void main() => runApp(MyApp());

const String ssd = "SSD MobileNet";

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      home: TfliteHome(),
    );
  }
}

class TfliteHome extends StatefulWidget {
  @override
  _TfliteHomeState createState() => _TfliteHomeState();
}

class _TfliteHomeState extends State<TfliteHome> {
  String _model = ssd;
  File _image;

  double _imageWidth;
  double _imageHeight;
  bool _busy = false;
  List _recognitions;

  @override
  void initState() {
    super.initState();
    _busy = true;
    loadModel().then((val) {
      setState(() {
        _busy = false;
      });
    });
  }

  loadModel() async {
    Tflite.close();
    try {
      String res;
      if (_model == ssd) {
        res = await Tflite.loadModel(
          model: "assets/tflite/detect.tflite",
          labels: "assets/tflite/labelmap.txt",
        );
      }
      print(res);
    } on PlatformException {
      print("Failed to Load model");
    }
  }

  selectImageFromPicker() async {
    final image =
        await ImagePicker.pickImage(source: ImageSource.camera, maxWidth: 600);
    if (image == null) return;
    setState(() {
      _busy = true;
    });
    predictImage(image);
    setState(() {
      _busy = false;
    });
  }

  predictImage(File image) async {
    if (image == null) return;
    if (_model == ssd) {
      await ssdMobileNet(image);
    } else {
      print("No model choosen");
    }

    FileImage(image)
        .resolve(ImageConfiguration())
        .addListener((ImageStreamListener((ImageInfo info, bool _) {
          setState(() {
            _imageWidth = info.image.width.toDouble();
            _imageHeight = info.image.height.toDouble();
          });
        })));
    setState(() {
      _image = image;
      _busy = false;
    });
  }

  ssdMobileNet(File image) async {
    final recognition = await Tflite.detectObjectOnImage(
      path: image.path,
      numResultsPerClass: 1,
      threshold: 0.5,
    );
    print(recognition.map((re) {
      return re["confidenceInClass"] * 100 >= 50.0;
    }));
    //print(recognition[0]['confidenceInClass']);
    setState(() {
      _recognitions = recognition;
    });
  }

  // now we r gonna draw some boxes on img
  List<Widget> renderBoxes(Size screen) {
    if (_recognitions == null) return [];
    if (_imageWidth == null || _imageHeight == null) return [];

    double factorX = math.min(screen.height, screen.width); //screen.width;
    double factorY = math.max(screen.height, screen.width);  //(_imageHeight / _imageHeight) * screen.width;
    Color blue = Colors.blue;

    return _recognitions.map((re) {
      return Positioned(
        left: re['rect']['x'] * factorX,
        top: re['rect']['y'] * factorY,
        width: re['rect']['w'] * factorX,
        height: re['rect']['h'] * factorY,
        child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: blue,
                width: 3,
              ),
            ),
            child: Text(
              "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
              style: TextStyle(
                background: Paint()..color = blue,
                color: Colors.white,
                fontSize: 15,
              ),
            )),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    List<Widget> stackChildren = [];

    stackChildren.add(Positioned(
      top: 0.0,
      left: 0.0,
      width: size.width,
      height: size.height,
      child: _image == null
          ? Center(child: Text("No Image Selected"))
          : Image.file(
              _image,
              fit: BoxFit.cover,
            ),
    ));

    stackChildren.addAll(renderBoxes(size));

    if (_busy) {
      stackChildren.add(
        Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Tflite Magic"),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.camera),
        tooltip: "Take a picture",
        onPressed: selectImageFromPicker,
      ),
      body: Stack(
        children: stackChildren,
      ),
    );
  }
}
