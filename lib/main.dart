import 'dart:html' show AudioElement, document;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:audioplayers/audio_cache.dart';

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
  // サンプラーを保持する
  final List<Sampler> _samplers = <Sampler>[];

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

  /// 取得したスナップショットからサンプラーボタンを作る
  Widget _buildList(List<DocumentSnapshot> snapshots) {
    if (_samplers.length == 0) {
      // サンプラーの初期化
      _initSampler(snapshots);
    } else {
      // サンプル種類ごとにf確認
      for (final snapshot in snapshots) {
        // サンプラー取得
        Sampler sampler = _searchSampler(snapshot.data()["type"]);

        if (sampler != null) {
          // 再生数がローカルと変わっていて、かつ0でなかったら再生
          if (sampler.times != snapshot.data()["times"] &&
              snapshot.data()["times"] != 0) {
            sampler.play();
          }
          // サンプラーののローカルの値をサーバーの値と同期
          sampler.times = snapshot.data()["times"];
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.only(top: 20.0),
      children: snapshots.map((data) {
        return _buildListItem(data);
      }).toList(),
    );
  }

  /// サンプラーを初期化
  void _initSampler(List<DocumentSnapshot> snapshots) {
    for (final data in snapshots) {
      _samplers.add(Sampler(data));
    }
  }

  /// サンプラーの名前から目的のサンプラーを取得
  Sampler _searchSampler(String sampleType) {
    if (_samplers.length == 0) {
      return null;
    }

    try {
      final returnSampler = _samplers
          .where((sampler) => sampler.sampleType == sampleType)
          .toList()
          .first;

      return returnSampler;
    } catch (e) {
      // 見つからなかった場合はnull
      return null;
    }
  }

  Widget _buildListItem(DocumentSnapshot data) {
    // サンプラーのタイプを指定して取得
    Sampler sampler = _searchSampler(data.data()["type"]);

    if (sampler == null) {
      // フェールセーフ
      return LinearProgressIndicator();
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
              // 再生回数をリセット
              sampler.reference.update({'times': 0});
              sampler.reset();
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
            // firebase側をincrement
            sampler.reference.update({'times': FieldValue.increment(1)});
            // 再生して再生数をインクリメント
            sampler.play();
            sampler.increment();
          },
        ),
      ),
    );
  }
}

/// サンプラー
class Sampler {
  /// サンプルの種類
  String sampleType;

  /// 押された回数
  int times;

  /// DocumentReference
  DocumentReference reference;

  /// snapshotを使ったコンストラクタ
  Sampler(DocumentSnapshot snapshot) {
    var map = snapshot.data();
    this.sampleType = map['type'];
    this.times = map['times'];
    this.reference = snapshot.reference;
  }

  /// 再生数をインクリメント
  void increment() {
    this.times++;
  }

  /// 再生数をリセット
  void reset() {
    this.times = 0;
  }

  /// サンプルを再生
  void play() {
    if (kIsWeb) {
      // webの場合はAudioElementsで再生
      final AudioElement audioElement = AudioElement();
      String url = "./assets/assets/$sampleType.wav";
      audioElement.id = sampleType;
      audioElement.src = url;
      document.body.append(audioElement);
      audioElement.play();
    } else {
      // ネイティブの場合はAudioCacheで再生
      final AudioCache _player = AudioCache();
      String filename = "$sampleType.wav";
      _player.play(filename);
    }
  }
}
