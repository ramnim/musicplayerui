import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:audioplayer/audioplayer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wave_progress_bars/wave_progress_bars.dart';

typedef void OnError(Exception exception);

void printWrapped(String text) {
  final pattern = RegExp('.{1,800}');
  pattern.allMatches(text).forEach((match) {
    print(match.group(0));
  });
}

class SearchPlay extends StatefulWidget {
  @override
  SearchPlayState createState() => SearchPlayState();
}

enum PlayerState { stopped, playing, paused}

class SearchPlayState extends State<SearchPlay> {
  List<dynamic> _resultList;
  AudioPlayer _audioPlayer;
  AudioProvider _audioProvider;
  bool _loadedSongs;
  int _skipSeconds = 5;
  String _localAudioFile;
  Future<List<InternetAddress>> _internetAddressListFuture;
  int _currentTile;
  IconData _playPause = Icons.pause;
  bool _busy = false;
  double _width; // width of screen
  double _height; // height of screen
  StreamSubscription _positionSubscription;
  StreamSubscription _stateSubscription;
  Duration _position;
  Duration _duration;
  PlayerState _playerState = PlayerState.stopped;
  bool _songSelected = false;

  void initState() {
    super.initState();
    //_internetAddressListFuture = InternetAddress.lookup('google.com');
    _loadedSongs = false;
    _audioPlayer = AudioPlayer();
    _positionSubscription = _audioPlayer.onAudioPositionChanged.listen((p) {
      setState(() {
        _position = p;
      });
    });
    _stateSubscription = _audioPlayer.onPlayerStateChanged.listen((s) {
      if (s == AudioPlayerState.PLAYING) {
        setState(() {
          _duration = _audioPlayer.duration;
        });
      } else if (s == AudioPlayerState.STOPPED) {
        setState( () {
          _playerState = PlayerState.stopped;
        });
      }
    },
    onError: (msg) {
      setState(() {
        _playerState = PlayerState.stopped;
        _duration = Duration(seconds: 0);
        _position = Duration(seconds: 0);
      });
    }
    );
  }

  Widget _searchBar() {
    return Container(
      height: 40.0,
      margin: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue,),
      ),
      child: TextField(
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search, color: Colors.grey,),
          hintText: AppLocale.of(context).translate('searchServices'),
          border: InputBorder.none,
        ),
        onSubmitted: (value) async {
          String _text = value.replaceAll(' ', '+');
          setState( () {
            _busy = true;
          });
          Response _response =
          await get('https://itunes.apple.com/search?term=$_text');
          setState( () {
            _busy = false;
          });
          var _resultMap = jsonDecode(_response.body);
          int _resultCount = _resultMap['resultCount'];
          if (_resultCount > 0) {
            _loadedSongs = true;
          } else {
            _loadedSongs = false;
            return;
          }
          _resultList = _resultMap['results'];
          setState(() {});
        },
      ) ,
    );
  }
  Widget _songList() {
    if (_loadedSongs) {
      return Expanded (
        //width: _width,
        //height: _height * 0.75,
        child: ListView.builder(
          itemBuilder: (context, count) {
            String _title = _resultList[count]['trackName'];
            if (_title == null || _title.length < 1) {
              _title = 'Not Available';
            }
            String _artistName = _resultList[count]['artistName'];
            if (_artistName == null || _artistName.length < 1) {
              _artistName = 'Not Available';
            }
            String _collectionName = _resultList[count]['collectionName'];
            if (_collectionName == null || _collectionName.length < 1) {
              _collectionName = 'Not Available';
            }
            return ListTile(
              title: Text (_title, overflow: TextOverflow.ellipsis,),
              subtitle: Text(_artistName + '\n' + _collectionName, overflow: TextOverflow.ellipsis,),
              isThreeLine: true,
              leading: _resultList[count]['artworkUrl60'] != null
                  ? Image.network(
                _resultList[count]['artworkUrl60'],
                width: 55, fit: BoxFit.contain,
              ) : Container(),
              trailing: _currentTile == count ?
              Container(
                width: 35, height: 35,
                child: WaveProgressBar(
                  progressPercentage: 100,
                  listOfHeights: _values,
                  width: 30,
                  initalColor: Colors.white,
                  progressColor: Colors.blue[800],
                  backgroundColor: Colors.white,
                  timeInMilliSeconds: 1000,
                  isHorizontallyAnimated: true,
                  isVerticallyAnimated: true,
                ),
              ) : Container(width:25),
              onTap: () async {
	              _songSelected = true;
                setState( (){
                  _currentTile = count;
                  _playPause = Icons.pause;
                });
                _audioPlayer.stop();
                AudioProvider _audioProvider =
                  AudioProvider(_resultList[count]['previewUrl']);
                _localAudioFile = await _audioProvider.load();
                _audioPlayer.play(_localAudioFile, isLocal: true);
              },
            );
          },
          itemCount: _resultList.length,
          shrinkWrap: true,
        ),
      );
    } else {
      return Container();
    }
  }
  Widget _playPauseSkip() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(icon: Icon(Icons.skip_previous, size: 35,),
          onPressed: () {
            Duration _duration = _audioPlayer.duration;
            int _secs = _duration.inSeconds;
            double _newPositionSecs =
            (_secs - _skipSeconds).toDouble();
            if (_newPositionSecs < 0) _newPositionSecs = 0;
            if (_secs > 0) {
              if (_audioPlayer != null)
                _audioPlayer.seek(_newPositionSecs);
              if (_audioPlayer != null && _localAudioFile !=
                  null)
                _audioPlayer.play(_localAudioFile, isLocal: true);
            }
          },
        ),
        IconButton(
          icon: Icon(_playPause, size: 35),
          onPressed: () {
            if (_playPause == Icons.play_arrow) {
              _audioPlayer.seek(0.0);
              _audioPlayer.play(_localAudioFile, isLocal: true);
            } else {
              if (_audioPlayer != null) _audioPlayer.pause();
            }
            setState(() {
              _playPause =
                _playPause == Icons.play_arrow ? Icons.pause : Icons .play_arrow;
            });
          },
        ),
        IconButton(
          icon: Icon(Icons.skip_next, size: 35),
          onPressed: () {
            Duration _duration = _audioPlayer.duration;
            int _secs = _duration.inSeconds;
            double _newPositionSecs =
            (_secs + _skipSeconds).toDouble();
            _audioPlayer.seek(_newPositionSecs);
            if (_audioPlayer != null && _localAudioFile != null)
              _audioPlayer.play(_localAudioFile, isLocal: true);
          },
        ),
      ],
    );
  }
  Widget _progressBar() {
    return Slider (
      min: 0.0,
      max: _duration?.inMilliseconds?.toDouble() ?? 5000,
      value: _position?.inMilliseconds?.toDouble() ?? 0.0,
      onChanged: (double value) {
        return _audioPlayer.seek((value/1000).toDouble());
      },
    );
  }
  Widget _audioControls () {
    if (_songSelected) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          color: Colors.grey[200],
          padding: EdgeInsets.only(top: 8, bottom: 8),
          child: Column (
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            mainAxisSize: MainAxisSize.min,
            children: [
              _playPauseSkip(),
              _progressBar(),
            ],
          ),
        ),
      );
    } else {
      return Container();
    }
  }

  Widget _content(BuildContext context) {
    if (!_busy) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
            children: <Widget>[
              Column(
                children: [
                  SizedBox(height: 30,),
                  _searchBar(),
                  _songList(),
                ],
              ),
              _audioControls(),
            ]
        ),
      );
    } else {
      return Scaffold(body:Center(child: CircularProgressIndicator(),));
    }
  }

  Timer _timer;

  void _refresh() {
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      print('--- check internet -----');
      setState(() {});
    });
  }

  @override
  void dispose() {
    if (_timer != null) _timer.cancel();
    super.dispose();
  }

  final List<double> _values = [];

  @override
  Widget build(BuildContext context) {
    _width = MediaQuery.of(context).size.width;
    _height = MediaQuery.of(context).size.height;
    _internetAddressListFuture = InternetAddress.lookup('google.com');
    var rng = new Random();
    for (var i = 0; i < 10; i++) {
      _values.add(rng.nextInt(30) * 1.0);
    }
    return FutureBuilder(
      future: _internetAddressListFuture,
      builder: (futureContext, AsyncSnapshot<List<InternetAddress>> snapshot) {
        Widget _returnWidget = Container();
        if (snapshot.hasData) {
          List<InternetAddress> _internetAddressList = snapshot.data;
          if (_internetAddressList.isNotEmpty &&
              _internetAddressList[0].rawAddress.isNotEmpty) {
            _returnWidget = _content(context);
          }
        } else {
          _returnWidget = Material(
            child: Center(
              child: Container(
                padding: EdgeInsets.all(10),
                child: Text('No internet. Enable WiFi or mobile Network to proceed'),
              ),
            ),
          );
        }
        return _returnWidget;
      },
    );
  }
}

class AudioProvider {
  String url;

  AudioProvider(this.url);

  Future<Uint8List> _loadFileBytes(String url, {OnError onError}) async {
    Uint8List bytes;
    try {
      bytes = await readBytes(url);
    } on ClientException {
      rethrow;
    }
    return bytes;
  }

  Future<String> load() async {
    final bytes = await _loadFileBytes(url, onError: (Exception exception) {
      print('audio_provider.load: exception $exception');
    });
    final dir = await getApplicationDocumentsDirectory();
    final file = new File('${dir.path}/audio.m4a');
    await file.writeAsBytes(bytes);
    if (await file.exists()) {
      return file.path;
    }
    return '';
  }
}

class AppLocale {
  final Locale appLocale;

  AppLocale(this.appLocale);

  static AppLocale of(BuildContext context) {
    return Localizations.of<AppLocale>(context, AppLocale);
  }

  Map<String, String> _localizedStrings;

  Future<bool> load() async {
    String jsonString = await rootBundle.loadString(
        'resources/languages/${appLocale.languageCode}.json');
    Map<String, dynamic> jsonLanguageMap = json.decode(jsonString);
    _localizedStrings = jsonLanguageMap.map((key, value) {
      return MapEntry(key, value.toString());
    });
    return true;
  }

  String translate(String jsonKey) {
    return _localizedStrings[jsonKey];
  }

  static const LocalizationsDelegate<AppLocale> delegate = _AppLocaleDelegate();
}

class _AppLocaleDelegate extends LocalizationsDelegate<AppLocale> {
  const _AppLocaleDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'te'].contains(locale.languageCode);
  }

  @override
  Future<AppLocale> load(Locale locale) async {
    AppLocale localizations = AppLocale(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocaleDelegate old) => false;
}
