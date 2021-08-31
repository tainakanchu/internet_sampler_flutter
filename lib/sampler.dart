import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_audio/just_audio.dart';

/// サンプラー
class Sampler {
  /// サンプルの種類
  late String sampleType;

  /// サンプルのURL (sampleType.wavで決め打ち)
  late String sampleUrl;

  /// 押された回数
  late int times;

  /// DocumentReference
  late DocumentReference reference;

  /// snapshotを使ったコンストラクタ
  Sampler(DocumentSnapshot snapshot) {
    Map snapshotData = snapshot.data() as Map<dynamic, dynamic>;
    this.sampleType = snapshotData['type'];
    this.times = snapshotData['times'];
    this.reference = snapshot.reference;
    this.sampleUrl = "assets/$sampleType.wav";
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
  void play() async {
    final AudioPlayer _player = AudioPlayer();
    await _player.setAsset(sampleUrl);
    _player.play();
  }
}
