import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() {
  runApp(const MaterialApp(
    home: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _localVideoRenderer = RTCVideoRenderer();
  final _remoteVideoRenderer = RTCVideoRenderer();
  final sdpController = TextEditingController();
  bool _offer = false;


  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  void initRenderers() async {
    await _localVideoRenderer.initialize();
    await _remoteVideoRenderer.initialize();
  }

  _getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': false

    };
    MediaStream localStream;


    localStream =
        await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localVideoRenderer.srcObject = _localStream;
    return localStream;

  }


  Future _createPeerConnection() async{
    Map<String, dynamic> configuration = {
      // "iceServers": [
      //   {"url": "stun:stun.l.google.com:19302"},
      // ]
      "sdpSemantics": "plan-b", // Add this line
      'iceServers': [
        {
          'urls': [
            "stun:stun.l.google.com:19302"
            // ice server urls
          ]
        }
      ]
    };
    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
      },
      "optional": [],
    };
    _localStream = await _getUserMedia();
    RTCPeerConnection pc =
    await createPeerConnection(configuration, offerSdpConstraints);
    pc.addStream(_localStream!);
    print("print from add local stream${pc.addStream(_localStream!)}");
    pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        print("print from ice ${json.encode({
          'candidate': e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMlineIndex': e.sdpMLineIndex,
        })}");
      }
    };
    pc.onIceConnectionState = (e) {
      print("print from state $e");
    };
    pc.onAddStream = (stream) {
      print('addStream: ' + stream.id);
      _remoteVideoRenderer.srcObject = stream;
    };
    return pc;
  }
  void _createOffer() async {
    RTCSessionDescription description =
    await _peerConnection!.createOffer({'offerToReceiveVideo': 1});
    var session = parse(description.sdp.toString());
    print(json.encode(session));
    _offer = true;

    _peerConnection!.setLocalDescription(description);
  }
  void _createAnswer() async {
    RTCSessionDescription description =
    await _peerConnection!.createAnswer({'offerToReceiveVideo': 1});

    var session = parse(description.sdp.toString());
    print(json.encode(session));

    _peerConnection!.setLocalDescription(description);
  }
  void _setRemoteDescription() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode(jsonString);

    String sdp = write(session, null);

    RTCSessionDescription description =
    RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');
    print(description.toMap());

    await _peerConnection!.setRemoteDescription(description);
  }
  void _addCandidate() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode(jsonString);
    print(session['candidate']);
    dynamic candidate = RTCIceCandidate(
        session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
    await _peerConnection!.addCandidate(candidate);
  }

  @override
  void initState() {
    super.initState();

   Future.delayed(Duration.zero,() async{
     initRenderers();
     _peerConnection =  await _createPeerConnection();

     print("print of peerconnection $_peerConnection");
   });

  }
  @override
  Future<void> dispose() async {
    // TODO: implement dispose
    await _localVideoRenderer.dispose();
    sdpController.dispose();
    super.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("test"),
      ),
      body: Column(
        children: [
          videoRenderers(),
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.5,
                  child: TextField(
                    controller: sdpController,
                    keyboardType: TextInputType.multiline,
                    maxLines: 4,
                    maxLength: TextField.noMaxLength,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _createOffer,
                    child: const Text("Offer"),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  ElevatedButton(
                    onPressed: _createAnswer,
                    child: const Text("Answer"),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  ElevatedButton(
                    onPressed: _setRemoteDescription,
                    child: const Text("Set Remote Description"),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  ElevatedButton(
                    onPressed: _addCandidate,
                    child: const Text("Set Candidate"),
                  ),
                ],
              )
            ],
          )
        ],
      ),
    );


  }
  SizedBox videoRenderers() => SizedBox(
    height: 210,
    child: Row(children: [
      Flexible(
        child: Container(
          key: const Key('local'),
          margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
          decoration: const BoxDecoration(color: Colors.black),
          child: RTCVideoView(_localVideoRenderer),
        ),
      ),
      Flexible(
        child: Container(
          key: const Key('remote'),
          margin: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
          decoration: const BoxDecoration(color: Colors.black),
          child: RTCVideoView(_remoteVideoRenderer),
        ),
      ),
    ]),
  );
}
