import 'dart:convert';
import 'package:flutter/material.dart';
// For using PlatformException
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:avatar_glow/avatar_glow.dart';

void main() => runApp(BluetoothApp());

class BluetoothApp extends StatefulWidget {
  @override
  _BluetoothAppState createState() => _BluetoothAppState();
}

class _BluetoothAppState extends State<BluetoothApp> {
  stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = 'Press the button and start speaking';

  // Initializing the Bluetooth connection state to be unknown
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  // Initializing a global key, as it would help us in showing a SnackBar later
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  // Get the instance of the Bluetooth
  FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;
  // Track the Bluetooth connection with the remote device
  BluetoothConnection connection;

  bool isDisconnecting = false;

  // To track whether the device is still connected to Bluetooth
  bool get isConnected => connection != null && connection.isConnected;

  // Define some variables, which will be required later
  List<BluetoothDevice> _devicesList = [];
  BluetoothDevice _device;
  bool _connected = false;
  bool _isButtonUnavailable = false;

  @override
  void initState() {
    super.initState();

    _speech = stt.SpeechToText();

    // Get current state
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    // If the bluetooth of the device is not enabled, then request
    // permission to turn on bluetooth as the app starts up
    enableBluetooth();

    // Listen for further state changes
    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;
        if (_bluetoothState == BluetoothState.STATE_OFF) {
          _isButtonUnavailable = true;
        }
        getPairedDevices();
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    // Avoid memory leak and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection.dispose();
      connection = null;
    }
  }

  // Request Bluetooth permission from the user
  Future<void> enableBluetooth() async {
    // Retrieving the current Bluetooth state
    _bluetoothState = await FlutterBluetoothSerial.instance.state;

    // If the bluetooth is off, then turn it on first
    // and then retrieve the devices that are paired.
    if (_bluetoothState == BluetoothState.STATE_OFF) {
      await FlutterBluetoothSerial.instance.requestEnable();
      await getPairedDevices();
      return true;
    } else {
      await getPairedDevices();
    }
    return false;
  }

  // For retrieving and storing the paired devices in a list.
  Future<void> getPairedDevices() async {
    List<BluetoothDevice> devices = [];

    // To get the list of paired devices
    try {
      devices = await _bluetooth.getBondedDevices();
    } on PlatformException {
      print("Error");
    }

    // It is an error to call [setState] unless [mounted] is true.
    if (!mounted) {
      return;
    }

    // Store the [devices] list in the [_devicesList] for accessing
    // the list outside this class
    setState(() {
      _devicesList = devices;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Door Lock',
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: Color(0xFF131d2e),
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text("Bluetooth Locking System"),
          backgroundColor: Color(0xFF42537F),
          actions: <Widget>[
            FlatButton.icon(
              icon: Icon(Icons.refresh),
              label: Text(
                "Refresh",
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              splashColor: Colors.deepPurple,
              onPressed: () async {
                // So, that when new devices are paired while the app is
                // running, user can refresh the paired devices list.
                await getPairedDevices().then((_) {
                  show('Device list refreshed');
                });
              },
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: AvatarGlow(
          animate: _isListening,
          glowColor: Theme.of(context).primaryColor,
          endRadius: 75.0,
          duration: const Duration(milliseconds: 2000),
          repeatPauseDuration: const Duration(milliseconds: 100),
          repeat: true,
          child: FloatingActionButton(
            onPressed: _listen,
            child: Icon(_isListening ? Icons.mic : Icons.mic_none),
          ),
        ),
        body: Container(
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Visibility(
                visible: _isButtonUnavailable &&
                    _bluetoothState == BluetoothState.STATE_ON,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.yellow,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Enable Bluetooth',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Switch(
                      value: _bluetoothState.isEnabled,
                      onChanged: (bool value) {
                        future() async {
                          if (value) {
                            await FlutterBluetoothSerial.instance
                                .requestEnable();
                          } else {
                            await FlutterBluetoothSerial.instance
                                .requestDisable();
                          }

                          await getPairedDevices();
                          _isButtonUnavailable = false;

                          if (_connected) {
                            _disconnect();
                          }
                        }

                        future().then((_) {
                          setState(() {});
                        });
                      },
                    )
                  ],
                ),
              ),
              Column(
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          "PAIRED DEVICES",
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFceeeff)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            Text(
                              'Device:',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10.0),
                              child: DropdownButton(
                                items: _getDeviceItems(),
                                onChanged: (value) =>
                                    setState(() => _device = value),
                                value: _devicesList.isNotEmpty ? _device : null,
                              ),
                            ),
                            IconButton(
                                icon: Icon(
                                  Icons.settings,
                                  size: 32,
                                ),
                                onPressed: () {
                                  FlutterBluetoothSerial.instance
                                      .openSettings();
                                })
                          ],
                        ),
                      ),
                      RaisedButton(
                        onPressed: _isButtonUnavailable
                            ? null
                            : _connected
                                ? _disconnect
                                : _connect,
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Text(
                            _connected ? 'Disconnect' : 'Connect',
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                              color: Color(0xFF03A9F4),
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: <Widget>[
                              SizedBox(width: 20),
                              Expanded(
                                child: Text(
                                  "Door (Lock/Unlock)",
                                  style: TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              FlatButton(
                                onPressed: () {
                                  if (_connected)
                                    _sendMessageToBluetooth(
                                        send: 0, message: 'unlocking door');
                                },
                                child: Text(
                                  "Unlock",
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 20),
                                ),
                              ),
                              SizedBox(width: 10),
                              FlatButton(
                                onPressed: () {
                                  if (_connected)
                                    _sendMessageToBluetooth(
                                        send: 1, message: 'locking door');
                                },
                                child: Text(
                                  "Lock",
                                  style: TextStyle(
                                      color: Color(0xFF388E3C), fontSize: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                              color: Color(0xFF03A9F4),
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: <Widget>[
                              SizedBox(width: 20),
                              Expanded(
                                child: Text(
                                  "Door (Open/Close)",
                                  style: TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              FlatButton(
                                onPressed: () {
                                  if (_connected)
                                    _sendMessageToBluetooth(
                                        send: 3, message: 'closing door');
                                },
                                child: Text(
                                  "Close",
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 20),
                                ),
                              ),
                              SizedBox(width: 10),
                              FlatButton(
                                onPressed: () {
                                  if (_connected)
                                    _sendMessageToBluetooth(
                                        send: 4, message: 'opening door');
                                },
                                child: Text(
                                  "Open",
                                  style: TextStyle(
                                      color: Color(0xFF388E3C), fontSize: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _text = val.recognizedWords;
            List s = _text.split(' ');
            for (String word in s) {
              if (word.toLowerCase() == 'lock') {
                print('lock');
                _sendMessageToBluetooth(send: 1, message: 'locking door');
              } else if (word.toLowerCase() == 'unlock') {
                print('unlock');
                _sendMessageToBluetooth(send: 0, message: 'unlocking door');
              } else if (word.toLowerCase() == 'close') {
                print('close');
                _sendMessageToBluetooth(send: 3, message: 'closing door');
              } else if (word.toLowerCase() == 'open') {
                print('open');
                _sendMessageToBluetooth(send: 4, message: 'opening door');
              }
            }
            _text = '';
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // Create the List of devices to be shown in Dropdown Menu
  List<DropdownMenuItem<BluetoothDevice>> _getDeviceItems() {
    List<DropdownMenuItem<BluetoothDevice>> items = [];
    if (_devicesList.isEmpty) {
      items.add(DropdownMenuItem(
        child: Text('NONE'),
      ));
    } else {
      _devicesList.forEach((device) {
        items.add(DropdownMenuItem(
          child: Text(device.name),
          value: device,
        ));
      });
    }
    return items;
  }

  // Method to connect to bluetooth
  void _connect() async {
    setState(() {
      _isButtonUnavailable = true;
    });
    if (_device == null) {
      show('No device selected');
    } else {
      if (!isConnected) {
        await BluetoothConnection.toAddress(_device.address)
            .then((_connection) {
          print('Connected to the device');
          connection = _connection;
          setState(() {
            _connected = true;
          });

          connection.input.listen(null).onDone(() {
            if (isDisconnecting) {
              print('Disconnecting locally!');
            } else {
              print('Disconnected remotely!');
            }
            if (this.mounted) {
              setState(() {});
            }
          });
        }).catchError((error) {
          print('Cannot connect, exception occurred');
          print(error);
        });
        show('Device connected');

        setState(() => _isButtonUnavailable = false);
      }
    }
  }

  // Method to disconnect bluetooth
  void _disconnect() async {
    setState(() {
      _isButtonUnavailable = true;
    });
    await connection.close();
    show('Device disconnected');
    if (!connection.isConnected) {
      setState(() {
        _connected = false;
        _isButtonUnavailable = false;
      });
    }
  }

  // Method to send message to Arduino using Bluetooth module
  void _sendMessageToBluetooth({int send, String message}) async {
    connection.output.add(utf8.encode("$send" + "\r\n"));
    await connection.output.allSent;
    show(message);
    setState(() {
      // device on
    });
  }

  // Method to show a SnackBar, taking message as the text
  Future show(
    String message, {
    Duration duration: const Duration(seconds: 2),
  }) async {
    await new Future.delayed(new Duration(milliseconds: 100));
    _scaffoldKey.currentState.showSnackBar(
      new SnackBar(
        content: new Text(
          message,
        ),
        duration: duration,
      ),
    );
  }

// void _onDataReceived(Uint8List data) {
//   // Allocate buffer for parsed data
//   int backspacesCounter = 0;
//   data.forEach((byte) {
//     if (byte == 8 || byte == 127) {
//       backspacesCounter++;
//     }
//   });
//   Uint8List buffer = Uint8List(data.length - backspacesCounter);
//   int bufferIndex = buffer.length;

//   // Apply backspace control character
//   backspacesCounter = 0;
//   for (int i = data.length - 1; i >= 0; i--) {
//     if (data[i] == 8 || data[i] == 127) {
//       backspacesCounter++;
//     } else {
//       if (backspacesCounter > 0) {
//         backspacesCounter--;
//       } else {
//         buffer[--bufferIndex] = data[i];
//       }
//     }
//   }
// }

}
