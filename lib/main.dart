import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rxdart/subjects.dart';

import 'notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Streams are created so that app can respond to notification-related events since the plugin is initialised in the `main` function
final BehaviorSubject<ReceivedNotification> didReceiveLocalNotificationSubject =
    BehaviorSubject<ReceivedNotification>();

final BehaviorSubject<String> selectNotificationSubject =
    BehaviorSubject<String>();

/// IMPORTANT: running the following code on its own won't work as there is setup required for each platform head project.
/// Please download the complete example app from the GitHub repository where all the setup has been done
void main() => runApp( MaterialApp(home: HomePage()));

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  
  NotificationService _service;
  static const platform = const MethodChannel('flutter.module.com/channelcommunication');
  String _message = "I'm a message";

  @override
  void initState() {
    super.initState();
    _requestIOSPermissions();
    _configureDidReceiveLocalNotificationSubject();
    _configureSelectNotificationSubject();

    _service = NotificationService(
      didReceiveLocalNotificationSubject,
      selectNotificationSubject,
      flutterLocalNotificationsPlugin, 
      platform
    );
  }

  Future<void> _sendPlatformMessage(String message, [Map<String, String> data]) async {
    String result = "An error has occured while sending a platform message";
    try {
      switch(message) {
        case "login":
          result = await platform.invokeMethod('login');
          break;
        case "logout":
          result = await platform.invokeMethod('logout');
          break;
        default:
          throw new PlatformException(code: "Platform Message Error", message: "Message not supported: ${message}");
      }
    } on PlatformException catch(e) {
      print("Failed to invoke method: '${e.message}'.");
      if(e.message.isNotEmpty) { result = e.message; }
    }

    setState(() {
      _message = result;
    });
  }

  void _requestIOSPermissions() {
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  void _configureDidReceiveLocalNotificationSubject() {
    didReceiveLocalNotificationSubject.stream
        .listen((ReceivedNotification receivedNotification) async {
      await showDialog(
        context: context,
        builder: (BuildContext context) => CupertinoAlertDialog(
          title: receivedNotification.title != null
              ? Text(receivedNotification.title)
              : null,
          content: receivedNotification.body != null
              ? Text(receivedNotification.body)
              : null,
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: Text('Ok'),
              // onPressed: () async {
              //   Navigator.of(context, rootNavigator: true).pop();
              //   await Navigator.push(
              //     context,
              //     MaterialPageRoute(
              //       builder: (context) =>
              //           SecondScreen(receivedNotification.payload),
              //     ),
              //   );
              // },
            )
          ],
        ),
      );
    });
  }

  void _configureSelectNotificationSubject() {
    selectNotificationSubject.stream.listen((String payload) async {
      await _service.onNotificationSelect(payload);
    });
  }

  @override
  void dispose() {
    didReceiveLocalNotificationSubject.close();
    selectNotificationSubject.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Salesforce Time"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RaisedButton(
              onPressed: () async { await _sendPlatformMessage("login"); },
              child: const Text('Log in', style: TextStyle(fontSize: 20)),
            ),
            RaisedButton(
              onPressed: () async { await _sendPlatformMessage("logout"); },
              child: const Text('Log Out', style: TextStyle(fontSize: 20)),
            ),
            Text(
              '$_message',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () async { 
      //     await _sendPlatformMessage("login");
      //   },
      //   tooltip: 'Increment',
      //   child: Icon(Icons.add),
      // ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
