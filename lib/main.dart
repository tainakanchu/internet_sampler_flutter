import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'sampler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

// テーマを定義
var myTheme = ThemeData.dark().copyWith(
  primaryColor: Color(0xff454545),
  primaryTextTheme: const TextTheme().copyWith(
    headline6: TextStyle().copyWith(
      color: Color(0xffF39067),
      fontWeight: FontWeight.bold,
    ),
  ),
  accentColor: Color(0xff454545),
  scaffoldBackgroundColor: Color(0xff3F444C),
);

class MyApp extends StatelessWidget {
  static FirebaseAnalytics analytics = FirebaseAnalytics();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(title: 'Internet Sampler'),
      theme: myTheme,
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: analytics),
      ],
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // サンプラーを保持する
  final List<Sampler> _samplers = <Sampler>[];

  final AppBar _appbar = AppBar(
    title: Text('Internet Sampler'),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appbar,
      body: SafeArea(child: _buildBody()),
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
        return _buildPadSequence(snapshot.data.docs);
      },
    );
  }

  /// 取得したスナップショットからサンプラーボタンを作る
  Widget _buildPadSequence(List<DocumentSnapshot> snapshots) {
    if (_samplers.length == 0) {
      // サンプラーの初期化
      _initSampler(snapshots);
    } else {
      // サンプル種類ごとにf確認
      for (final snapshot in snapshots) {
        Map snapshotData = snapshot.data() as Map<dynamic, dynamic>;
        // サンプラー取得
        Sampler? sampler = _searchSampler(snapshotData["type"]);

        if (sampler != null) {
          // 再生数がローカルと変わっていて、かつ0でなかったら再生
          if (sampler.times != snapshotData["times"] &&
              snapshotData["times"] != 0) {
            sampler.play();
          }
          // サンプラーののローカルの値をサーバーの値と同期
          sampler.times = snapshotData["times"];
        }
      }
    }

    return Container(
      padding: EdgeInsets.all(8.0),
      constraints: BoxConstraints.expand(),
      child: Center(
        child: Wrap(
          spacing: 16.0,
          alignment: WrapAlignment.spaceAround,
          children: snapshots.map((data) {
            return _buildSamplerPad(data);
          }).toList(),
        ),
      ),
    );
  }

  /// サンプラーを初期化
  void _initSampler(List<DocumentSnapshot> snapshots) {
    for (final data in snapshots) {
      _samplers.add(Sampler(data));
    }
  }

  /// サンプラーの名前から目的のサンプラーを取得
  Sampler? _searchSampler(String? sampleType) {
    if (_samplers.length == 0 || sampleType == null) {
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

  Widget _buildSamplerPad(DocumentSnapshot snapshot) {
    Map snapshotData = snapshot.data() as Map<dynamic, dynamic>;
    // サンプラーのタイプを指定して取得
    Sampler? sampler = _searchSampler(snapshotData["type"]);

    if (sampler == null) {
      // フェールセーフ
      return LinearProgressIndicator();
    }

    bool isLandscape =
        MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    const _buttonContentsColor = Color(0xffeeeeee);

    return Padding(
      padding: EdgeInsets.all(8.0),
      child: Container(
        width: isLandscape
            ? MediaQuery.of(context).size.longestSide / (_samplers.length + 0.5)
            : MediaQuery.of(context).size.shortestSide,
        height: isLandscape
            ? (MediaQuery.of(context).size.shortestSide -
                    _appbar.preferredSize.height) *
                0.8
            : (MediaQuery.of(context).size.longestSide -
                    _appbar.preferredSize.height) /
                (_samplers.length + 0.5),
        decoration: BoxDecoration(
          border: Border.all(
            color: Color(0xffF39067),
            width: MediaQuery.of(context).size.shortestSide * 0.017,
          ),
          borderRadius: BorderRadius.circular(6.0),
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            primary: Color(0xff1f1f1f),
            onPrimary: Color(0xffF39067),
          ),
          onPressed: () {
            // firebase側をincrement
            sampler.reference.update({'times': FieldValue.increment(1)});
            // 再生して再生数をインクリメント
            sampler.play();
            sampler.increment();
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              FittedBox(
                fit: BoxFit.fitWidth,
                child: Text(
                  sampler.sampleType,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: _buttonContentsColor,
                  ),
                ),
              ),
              Icon(
                Icons.speaker,
                size: 50,
                color: _buttonContentsColor,
              ),
              Text(
                sampler.times.toString(),
                style: TextStyle(color: _buttonContentsColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
