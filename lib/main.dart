import 'dart:html' show AudioElement, document;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:audioplayers/audio_cache.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  static FirebaseAnalytics analytics = FirebaseAnalytics();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(title: 'Internet Sampler'),
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: analytics),
      ],
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final Future<FirebaseApp> _initialization = Firebase.initializeApp();
    return FutureBuilder(
      future: _initialization,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return _streamBuilder();
        }
        return LinearProgressIndicator();
      },
    );
  }

  Widget _streamBuilder() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sampler').snapshots(),
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        if (!snapshot.hasData) {
          return LinearProgressIndicator();
        }
        return _buildList(snapshot.data.docs);
      },
    );
  }

  Widget _buildList(List<DocumentSnapshot> snapshot) {
    return ListView(
      padding: const EdgeInsets.only(top: 20.0),
      children: snapshot.map((data) {
        return _buildListItem(data);
      }).toList(),
    );
  }

  Widget _buildListItem(DocumentSnapshot data) {
    final sampler = Sampler(data);

    if (sampler.times > 0) {
      sampler.play();
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(6.0),
        ),
        child: ListTile(
            title: Text(sampler.sampleType),
            trailing: OutlinedButton(
              onPressed: () {
                sampler.reference.update({'times': 0});
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.delete,
                  ),
                  Text(sampler.times.toString()),
                ],
              ),
            ),
            onTap: () {
              sampler.reference.update({'times': FieldValue.increment(1)});
              // sampler.play();
            }),
      ),
    );
  }
}

/// サンプラー
class Sampler {
  String sampleType;
  int times;
  DocumentReference reference;
  AudioPlayer audioPlayer = AudioPlayer(mode: PlayerMode.LOW_LATENCY);

  Sampler(DocumentSnapshot snapshot) {
    var map = snapshot.data();
    this.sampleType = map['type'];
    this.times = map['times'];
    this.reference = snapshot.reference;
  }

  /// サンプルを再生
  void play() {
    if (kIsWeb) {
      // webの場合はAudioElementsで再生
      String url = "./assets/assets/$sampleType.wav";
      var audioElement = AudioElement();
      audioElement.id = sampleType;
      audioElement.src = url;
      document.body.append(audioElement);
      audioElement.play();
    } else {
      // ネイティブの場合はAudioCacheで再生
      String filename = "$sampleType.wav";
      final player = AudioCache();
      player.play(filename);
    }
  }
}
