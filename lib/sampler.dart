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

  final List<AudioPlayer> _players = [];

  /// snapshotを使ったコンストラクタ
  Sampler(DocumentSnapshot snapshot) {
    Map snapshotData = snapshot.data() as Map<dynamic, dynamic>;
    this.sampleType = snapshotData['type'];
    this.times = snapshotData['times'];
    this.reference = snapshot.reference;
    this.sampleUrl = "assets/$sampleType.wav";

    // 最初の3つぐらい適当に初期化
    for (var i = 0; i < 3; i++) {
      final _player = new AudioPlayer();
      _player.setAsset(sampleUrl);
      _players.add(_player);
    }
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
    // 使用可能なサンプラーを取得、使用可能なものが無かった時は新規作成
    final _player = _players.firstWhere((element) => element.playing == false,
        orElse: () => AudioPlayer());
    // audioSource が設定されていないときは作りたてのものなので初期化
    if (_player.audioSource == null) {
      await _player.setAsset(sampleUrl);
    }

    // 再生して、終了したら次の再生の準備
    await _player.play();
    await _player.pause();
    await _player.seek(Duration.zero);
  }
}
