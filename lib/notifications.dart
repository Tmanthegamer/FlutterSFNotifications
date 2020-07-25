import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/subjects.dart';
import 'package:url_launcher/url_launcher.dart';

const String CHANNEL_ID = 'SalesforceNotifications';
const String CHANNEL_NAME = 'SalesforceNotifications';
const String CHANNEL_DESCRIPTION = 'Channel Description';
const String CHANNEL = 'flutter.module.com/login';

class NotificationService {
  // Streams are created so that app can respond to notification-related events since the plugin is initialised in the `main` function
  final BehaviorSubject<ReceivedNotification> _didReceiveLocalNotificationSubject;
  final BehaviorSubject<String> _selectNotificationSubject;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  final MethodChannel _platform;
  int uniqueNumber;
  
  int get uniqueId {
    if(uniqueNumber == null) { uniqueNumber = 0; }
    return uniqueNumber++;
  }
  
  NotificationService( 
    this._didReceiveLocalNotificationSubject,
    this._selectNotificationSubject,
    this._flutterLocalNotificationsPlugin,
    this._platform
  ) {
    _asyncinit();
    _platform.setMethodCallHandler(_routeNotification);
  }

  NotificationAppLaunchDetails notificationAppLaunchDetails;
  
  void _asyncinit() async {
    // needed if you intend to initialize in the `main` function
    WidgetsFlutterBinding.ensureInitialized();

    notificationAppLaunchDetails =
        await _flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

    var initializationSettingsAndroid = AndroidInitializationSettings('sf__icon');
    // Note: permissions aren't requested here just to demonstrate that can be done later using the `requestPermissions()` method
    // of the `IOSFlutterLocalNotificationsPlugin` class
    var initializationSettingsIOS = IOSInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        onDidReceiveLocalNotification:
            (int id, String title, String body, String payload) async {
          _didReceiveLocalNotificationSubject.add(ReceivedNotification(
              id: id, title: title, body: body, payload: payload));
        });
    var initializationSettings = InitializationSettings(
        initializationSettingsAndroid, initializationSettingsIOS);
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onSelectNotification: (String payload) async {
        _selectNotificationSubject.add(payload);
      }
    );
  }

  Future<void> onNotificationSelect(String payload) async {
    if (_isURL(payload) && await canLaunch(payload)) {
      await launch(payload, forceSafariVC: false);
    }
  }

  bool _isURL(String payload) {
    return payload.isNotEmpty;
  }

  Future<dynamic> _routeNotification(MethodCall call) async {
    String payload;
    String body;
    String url;
    String notificationId;
    String title = 'Generic title';

    if(call.arguments['title'] != null)   { title   = call.arguments['title']; }
    if(call.arguments['body'] != null)    { body    = call.arguments['body']; }
    if(call.arguments['url'] != null)     { url     = call.arguments['url']; }
    if(call.arguments['payload'] != null) { payload = call.arguments['payload']; }

    notificationId = call.arguments['notificationId'] != null ? call.arguments['notificationId'] : this.uniqueId;
    if(payload == null && url.isNotEmpty) { payload = url; }
    
    var notification = ReceivedNotification(id: int.parse(notificationId), title: title, body: body, payload: payload, url: url);

    switch(call.method) {
      case 'SalesforceNotifications':
        await showNotification(notification);
        break;
    }
  }

  Future<void> showNotification(ReceivedNotification notification) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        CHANNEL_NAME, CHANNEL_NAME, CHANNEL_DESCRIPTION,
        importance: Importance.Max, priority: Priority.High, ticker: 'ticker');
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
        notification.id, notification.title, notification.body, platformChannelSpecifics,
        payload: notification.payload);
  }

  Future<void> _showNotificationWithNoBody(ReceivedNotification notification) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        CHANNEL_ID, CHANNEL_NAME, CHANNEL_DESCRIPTION,
        importance: Importance.Max, priority: Priority.High, ticker: 'ticker');
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
        notification.id, notification.title, null, platformChannelSpecifics,
        payload: notification.payload);
  }

  Future<void> _cancelNotification(int notificationId) async {
    await _flutterLocalNotificationsPlugin.cancel(notificationId);
  }

  Future<void> _showNotificationWithNoSound(ReceivedNotification notification) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        CHANNEL_ID,
        CHANNEL_NAME,
        CHANNEL_DESCRIPTION,
        playSound: false,
        styleInformation: DefaultStyleInformation(true, true));
    var iOSPlatformChannelSpecifics =
        IOSNotificationDetails(presentSound: false);
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    // await flutterLocalNotificationsPlugin.show(0, '<b>silent</b> title',
    //     '<b>silent</b> body', platformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(notification.id, notification.title,
        notification.body, platformChannelSpecifics);
  }

  Future<void> _showTimeoutNotification(ReceivedNotification notification, int timeoutAfter) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        CHANNEL_ID,
        CHANNEL_NAME,
        CHANNEL_DESCRIPTION,
        timeoutAfter: timeoutAfter,
        styleInformation: DefaultStyleInformation(true, true));
    var iOSPlatformChannelSpecifics =
        IOSNotificationDetails(presentSound: notification.playsound);
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(notification.id, notification.title,
        notification.body, platformChannelSpecifics);
  }

  Future<String> _downloadAndSaveFile(String url, String fileName) async {
    var directory = await getApplicationDocumentsDirectory();
    var filePath = '${directory.path}/$fileName';
    var response = await http.get(url);
    var file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  Future<List<PendingNotificationRequest>> _checkPendingNotificationRequests() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  Future<void> _cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> _showOngoingNotification(ReceivedNotification notification) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        CHANNEL_ID, CHANNEL_NAME, CHANNEL_DESCRIPTION,
        importance: Importance.Max,
        priority: Priority.High,
        ongoing: true,
        autoCancel: false);
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(notification.id, notification.title,
        notification.body, platformChannelSpecifics);
  }

  Future<void> _repeatNotification(ReceivedNotification notification) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        CHANNEL_ID,
        CHANNEL_NAME,
        CHANNEL_DESCRIPTION);
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.periodicallyShow(notification.id, notification.title,
        notification.body, RepeatInterval.EveryMinute, platformChannelSpecifics);
  }

  Future<void> _showDailyAtTime(ReceivedNotification notification, Time time) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        CHANNEL_ID,
        CHANNEL_NAME,
        CHANNEL_DESCRIPTION);
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.showDailyAtTime(
        notification.id,
        notification.title,
        notification.body,
        time,
        platformChannelSpecifics);
  }

  Future<void> _showWeeklyAtDayAndTime(ReceivedNotification notification, Day day, Time time) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        CHANNEL_ID,
        CHANNEL_NAME,
        CHANNEL_DESCRIPTION);
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.showWeeklyAtDayAndTime(
        notification.id,
        notification.title,
        notification.body,
        day,
        time,
        platformChannelSpecifics);
  }

  /// Android specific that doesn't show an update on the App icon
  Future<void> _showNotificationWithNoBadge(ReceivedNotification notification) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        CHANNEL_ID, CHANNEL_NAME, CHANNEL_DESCRIPTION,
        channelShowBadge: false,
        importance: Importance.Max,
        priority: Priority.High,
        onlyAlertOnce: true);
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
        notification.id, notification.title, notification.body, platformChannelSpecifics,
        payload: notification.payload);
  }

  /// Android specific that shows a progress notification
  Future<void> _showProgressNotification(ReceivedNotification notification, int maxProgress, int increment) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        CHANNEL_ID,
        CHANNEL_NAME,
        CHANNEL_DESCRIPTION,
        channelShowBadge: false,
        importance: Importance.Max,
        priority: Priority.High,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: maxProgress,
        progress: increment);
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
        notification.id,
        notification.title,
        notification.body,
        platformChannelSpecifics,
        payload: notification.payload);
  }

  /// Android specific that shows a progress notification
  Future<void> _showIndeterminateProgressNotification(ReceivedNotification notification) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        CHANNEL_ID,
        CHANNEL_NAME,
        CHANNEL_DESCRIPTION,
        channelShowBadge: false,
        importance: Importance.Max,
        priority: Priority.High,
        onlyAlertOnce: true,
        showProgress: true,
        indeterminate: true);
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
        notification.id,
        notification.title,
        notification.body,
        platformChannelSpecifics,
        payload: notification.payload);
  }

  /// Android specific, shows the notification regardless of privacy settings
  Future<void> _showPublicNotification(ReceivedNotification notification) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        CHANNEL_ID,
        CHANNEL_NAME,
        CHANNEL_DESCRIPTION,
        importance: Importance.Max,
        priority: Priority.High,
        ticker: 'ticker',
        visibility: NotificationVisibility.Public);
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
        notification.id, 
        notification.title,
        notification.body, 
        platformChannelSpecifics,
        payload: notification.payload);
  }

  /// iOS Specific to put in the number of notifications on the app icon
  Future<void> _showNotificationWithIconBadge(ReceivedNotification notification) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        CHANNEL_ID,
        CHANNEL_NAME,
        CHANNEL_DESCRIPTION);
    var iOSPlatformChannelSpecifics = IOSNotificationDetails(badgeNumber: 1);
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
        notification.id, notification.title, notification.body, platformChannelSpecifics,
        payload: notification.payload);
  }

  // Android specific which puts in a custom timestamp
  Future<void> _showNotificationWithCustomTimestamp(ReceivedNotification notification, DateTime datetime) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
      CHANNEL_ID,
      CHANNEL_NAME,
      CHANNEL_DESCRIPTION,
      importance: Importance.Max,
      priority: Priority.High,
      showWhen: true,
      when: datetime.millisecondsSinceEpoch,
    );
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
        notification.id, notification.title, notification.body, platformChannelSpecifics,
        payload: notification.payload);
  }

  Future<void> _showNotificationWithExternalAttachment(ReceivedNotification notification, String url, String filename) async {
    var bigPicturePath = await _downloadAndSaveFile(
        'http://via.placeholder.com/600x200', 'bigPicture.jpg');
    return _showNotificationWithAttachment(notification, bigPicturePath);
  }

  Future<void> _showNotificationWithAttachment(ReceivedNotification notification, String devicePath) async {
    var iOSPlatformChannelSpecifics = IOSNotificationDetails(
        attachments: [IOSNotificationAttachment(devicePath)]);
    var bigPictureAndroidStyle =
        BigPictureStyleInformation(FilePathAndroidBitmap(devicePath));
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        CHANNEL_ID, CHANNEL_NAME, CHANNEL_DESCRIPTION,
        importance: Importance.High,
        priority: Priority.High,
        styleInformation: bigPictureAndroidStyle);
    var notificationDetails = NotificationDetails(
        androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
        notification.id,
        notification.title,
        notification.body,
        notificationDetails);
  }

  Future<void> _deleteNotificationChannel(String channelId) async {
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.deleteNotificationChannel(channelId);
  }

  // Future<void> _showNotificationWithUpdatedChannelDescription() async {
  //   var androidPlatformChannelSpecifics = AndroidNotificationDetails(
  //       CHANNEL_ID,
  //       CHANNEL_NAME,
  //       'your updated channel description',
  //       importance: Importance.Max,
  //       priority: Priority.High,
  //       channelAction: AndroidNotificationChannelAction.Update);
  //   var iOSPlatformChannelSpecifics = IOSNotificationDetails();
  //   var platformChannelSpecifics = NotificationDetails(
  //       androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
  //   await flutterLocalNotificationsPlugin.show(
  //       0,
  //       'updated notification channel',
  //       'check settings to see updated channel description',
  //       platformChannelSpecifics,
  //       payload: notification.payload);
  // }

  // I don't see when this is useful
  // Future<void> _showNotificationWithoutTimestamp(ReceivedNotification notification) async {
  //   var androidPlatformChannelSpecifics = AndroidNotificationDetails(
  //       CHANNEL_ID, CHANNEL_NAME, CHANNEL_DESCRIPTION,
  //       importance: Importance.Max, priority: Priority.High, showWhen: false);
  //   var iOSPlatformChannelSpecifics = IOSNotificationDetails();
  //   var platformChannelSpecifics = NotificationDetails(
  //       androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
  //   await flutterLocalNotificationsPlugin.show(
  //       0, 'plain title', 'plain body', platformChannelSpecifics,
  //       payload: notification.payload);
  // }

  // Future<void> _showSoundUriNotification() async {
  //   // this calls a method over a platform channel implemented within the example app to return the Uri for the default
  //   // alarm sound and uses as the notification sound
  //   String alarmUri = await platform.invokeMethod('getAlarmUri');
  //   final x = UriAndroidNotificationSound(alarmUri);
  //   var androidPlatformChannelSpecifics = AndroidNotificationDetails(
  //       'uri channel id', 'uri channel name', 'uri channel description',
  //       sound: x,
  //       playSound: true,
  //       styleInformation: DefaultStyleInformation(true, true));
  //   var iOSPlatformChannelSpecifics =
  //       IOSNotificationDetails(presentSound: false);
  //   var platformChannelSpecifics = NotificationDetails(
  //       androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
  //   await flutterLocalNotificationsPlugin.show(
  //       0, 'uri sound title', 'uri sound body', platformChannelSpecifics);
  // }

  /// Schedules a notification that specifies a different icon, sound and vibration pattern
  // Future<void> _scheduleNotification() async {
  //   var scheduledNotificationDateTime =
  //       DateTime.now().add(Duration(seconds: 5));
  //   var vibrationPattern = Int64List(4);
  //   vibrationPattern[0] = 0;
  //   vibrationPattern[1] = 1000;
  //   vibrationPattern[2] = 5000;
  //   vibrationPattern[3] = 2000;

  //   var androidPlatformChannelSpecifics = AndroidNotificationDetails(
  //       'your other channel id',
  //       'your other channel name',
  //       'your other channel description',
  //       icon: 'secondary_icon',
  //       sound: RawResourceAndroidNotificationSound('slow_spring_board'),
  //       largeIcon: DrawableResourceAndroidBitmap('sample_large_icon'),
  //       vibrationPattern: vibrationPattern,
  //       enableLights: true,
  //       color: const Color.fromARGB(255, 255, 0, 0),
  //       ledColor: const Color.fromARGB(255, 255, 0, 0),
  //       ledOnMs: 1000,
  //       ledOffMs: 500);
  //   var iOSPlatformChannelSpecifics =
  //       IOSNotificationDetails(sound: 'slow_spring_board.aiff');
  //   var platformChannelSpecifics = NotificationDetails(
  //       androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
  //   await flutterLocalNotificationsPlugin.schedule(
  //       0,
  //       'scheduled title',
  //       'scheduled body',
  //       scheduledNotificationDateTime,
  //       platformChannelSpecifics);
  // }

  // There's no way I'm subjecting someone to this
  // Future<void> _showInsistentNotification() async {
  //   // This value is from: https://developer.android.com/reference/android/app/Notification.html#FLAG_INSISTENT
  //   var insistentFlag = 4;
  //   var androidPlatformChannelSpecifics = AndroidNotificationDetails(
  //       CHANNEL_ID, CHANNEL_NAME, CHANNEL_DESCRIPTION,
  //       importance: Importance.Max,
  //       priority: Priority.High,
  //       ticker: 'ticker',
  //       additionalFlags: Int32List.fromList([insistentFlag]));
  //   var iOSPlatformChannelSpecifics = IOSNotificationDetails();
  //   var platformChannelSpecifics = NotificationDetails(
  //       androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
  //   await flutterLocalNotificationsPlugin.show(
  //       0, 'insistent title', 'insistent body', platformChannelSpecifics,
  //       payload: notification.payload);
  // }

  // Future<void> _showBigPictureNotification() async {
  //   var largeIconPath = await _downloadAndSaveFile(
  //       'http://via.placeholder.com/48x48', 'largeIcon');
  //   var bigPicturePath = await _downloadAndSaveFile(
  //       'http://via.placeholder.com/400x800', 'bigPicture');
  //   var bigPictureStyleInformation = BigPictureStyleInformation(
  //       FilePathAndroidBitmap(bigPicturePath),
  //       largeIcon: FilePathAndroidBitmap(largeIconPath),
  //       contentTitle: 'overridden <b>big</b> content title',
  //       htmlFormatContentTitle: true,
  //       summaryText: 'summary <i>text</i>',
  //       htmlFormatSummaryText: true);
  //   var androidPlatformChannelSpecifics = AndroidNotificationDetails(
  //       'big text channel id',
  //       'big text channel name',
  //       'big text channel description',
  //       styleInformation: bigPictureStyleInformation);
  //   var platformChannelSpecifics =
  //       NotificationDetails(androidPlatformChannelSpecifics, null);
  //   await flutterLocalNotificationsPlugin.show(
  //       0, 'big text title', 'silent body', platformChannelSpecifics);
  // }

  // Future<void> _showBigPictureNotificationHideExpandedLargeIcon() async {
  //   var largeIconPath = await _downloadAndSaveFile(
  //       'http://via.placeholder.com/48x48', 'largeIcon');
  //   var bigPicturePath = await _downloadAndSaveFile(
  //       'http://via.placeholder.com/400x800', 'bigPicture');
  //   var bigPictureStyleInformation = BigPictureStyleInformation(
  //       FilePathAndroidBitmap(bigPicturePath),
  //       hideExpandedLargeIcon: true,
  //       contentTitle: 'overridden <b>big</b> content title',
  //       htmlFormatContentTitle: true,
  //       summaryText: 'summary <i>text</i>',
  //       htmlFormatSummaryText: true);
  //   var androidPlatformChannelSpecifics = AndroidNotificationDetails(
  //       'big text channel id',
  //       'big text channel name',
  //       'big text channel description',
  //       largeIcon: FilePathAndroidBitmap(largeIconPath),
  //       styleInformation: bigPictureStyleInformation);
  //   var platformChannelSpecifics =
  //       NotificationDetails(androidPlatformChannelSpecifics, null);
  //   await flutterLocalNotificationsPlugin.show(
  //       0, 'big text title', 'silent body', platformChannelSpecifics);
  // }

  // Future<void> _showNotificationMediaStyle() async {
  //   var largeIconPath = await _downloadAndSaveFile(
  //       'http://via.placeholder.com/128x128/00FF00/000000', 'largeIcon');
  //   var androidPlatformChannelSpecifics = AndroidNotificationDetails(
  //     'media channel id',
  //     'media channel name',
  //     'media channel description',
  //     largeIcon: FilePathAndroidBitmap(largeIconPath),
  //     styleInformation: MediaStyleInformation(),
  //   );
  //   var platformChannelSpecifics =
  //       NotificationDetails(androidPlatformChannelSpecifics, null);
  //   await flutterLocalNotificationsPlugin.show(
  //       0, 'notification title', 'notification body', platformChannelSpecifics);
  // }

  // Future<void> _showBigTextNotification() async {
  //   var bigTextStyleInformation = BigTextStyleInformation(
  //       'Lorem <i>ipsum dolor sit</i> amet, consectetur <b>adipiscing elit</b>, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.',
  //       htmlFormatBigText: true,
  //       contentTitle: 'overridden <b>big</b> content title',
  //       htmlFormatContentTitle: true,
  //       summaryText: 'summary <i>text</i>',
  //       htmlFormatSummaryText: true);
  //   var androidPlatformChannelSpecifics = AndroidNotificationDetails(
  //       'big text channel id',
  //       'big text channel name',
  //       'big text channel description',
  //       styleInformation: bigTextStyleInformation);
  //   var platformChannelSpecifics =
  //       NotificationDetails(androidPlatformChannelSpecifics, null);
  //   await flutterLocalNotificationsPlugin.show(
  //       0, 'big text title', 'silent body', platformChannelSpecifics);
  // }

  // Future<void> _showInboxNotification() async {
  //   var lines = List<String>();
  //   lines.add('line <b>1</b>');
  //   lines.add('line <i>2</i>');
  //   var inboxStyleInformation = InboxStyleInformation(lines,
  //       htmlFormatLines: true,
  //       contentTitle: 'overridden <b>inbox</b> context title',
  //       htmlFormatContentTitle: true,
  //       summaryText: 'summary <i>text</i>',
  //       htmlFormatSummaryText: true);
  //   var androidPlatformChannelSpecifics = AndroidNotificationDetails(
  //       'inbox channel id', 'inboxchannel name', 'inbox channel description',
  //       styleInformation: inboxStyleInformation);
  //   var platformChannelSpecifics =
  //       NotificationDetails(androidPlatformChannelSpecifics, null);
  //   await flutterLocalNotificationsPlugin.show(
  //       0, 'inbox title', 'inbox body', platformChannelSpecifics);
  // }

  // Future<void> _showMessagingNotification() async {
  //   // use a platform channel to resolve an Android drawable resource to a URI.
  //   // This is NOT part of the notifications plugin. Calls made over this channel is handled by the app
  //   String imageUri = await platform.invokeMethod('drawableToUri', 'food');
  //   var messages = List<Message>();
  //   // First two person objects will use icons that part of the Android app's drawable resources
  //   var me = Person(
  //     name: 'Me',
  //     key: '1',
  //     uri: 'tel:1234567890',
  //     icon: DrawableResourceAndroidIcon('me'),
  //   );
  //   var coworker = Person(
  //     name: 'Coworker',
  //     key: '2',
  //     uri: 'tel:9876543210',
  //     icon: FlutterBitmapAssetAndroidIcon('icons/coworker.png'),
  //   );
  //   // download the icon that would be use for the lunch bot person
  //   var largeIconPath = await _downloadAndSaveFile(
  //       'http://via.placeholder.com/48x48', 'largeIcon');
  //   // this person object will use an icon that was downloaded
  //   var lunchBot = Person(
  //     name: 'Lunch bot',
  //     key: 'bot',
  //     bot: true,
  //     icon: BitmapFilePathAndroidIcon(largeIconPath),
  //   );
  //   messages.add(Message('Hi', DateTime.now(), null));
  //   messages.add(Message(
  //       'What\'s up?', DateTime.now().add(Duration(minutes: 5)), coworker));
  //   messages.add(Message(
  //       'Lunch?', DateTime.now().add(Duration(minutes: 10)), null,
  //       dataMimeType: 'image/png', dataUri: imageUri));
  //   messages.add(Message('What kind of food would you prefer?',
  //       DateTime.now().add(Duration(minutes: 10)), lunchBot));
  //   var messagingStyle = MessagingStyleInformation(me,
  //       groupConversation: true,
  //       conversationTitle: 'Team lunch',
  //       htmlFormatContent: true,
  //       htmlFormatTitle: true,
  //       messages: messages);
  //   var androidPlatformChannelSpecifics = AndroidNotificationDetails(
  //       'message channel id',
  //       'message channel name',
  //       'message channel description',
  //       category: 'msg',
  //       styleInformation: messagingStyle);
  //   var platformChannelSpecifics =
  //       NotificationDetails(androidPlatformChannelSpecifics, null);
  //   await flutterLocalNotificationsPlugin.show(
  //       0, 'message title', 'message body', platformChannelSpecifics);

  //   // wait 10 seconds and add another message to simulate another response
  //   await Future.delayed(Duration(seconds: 10), () async {
  //     messages.add(
  //         Message('Thai', DateTime.now().add(Duration(minutes: 11)), null));
  //     await flutterLocalNotificationsPlugin.show(
  //         0, 'message title', 'message body', platformChannelSpecifics);
  //   });
  // }

  // Future<void> _showGroupedNotifications() async {
  //   var groupKey = 'com.android.example.WORK_EMAIL';
  //   var groupChannelId = 'grouped channel id';
  //   var groupChannelName = 'grouped channel name';
  //   var groupChannelDescription = 'grouped channel description';
  //   // example based on https://developer.android.com/training/notify-user/group.html
  //   var firstNotificationAndroidSpecifics = AndroidNotificationDetails(
  //       groupChannelId, groupChannelName, groupChannelDescription,
  //       importance: Importance.Max,
  //       priority: Priority.High,
  //       groupKey: groupKey);
  //   var firstNotificationPlatformSpecifics =
  //       NotificationDetails(firstNotificationAndroidSpecifics, null);
  //   await flutterLocalNotificationsPlugin.show(1, 'Alex Faarborg',
  //       'You will not believe...', firstNotificationPlatformSpecifics);
  //   var secondNotificationAndroidSpecifics = AndroidNotificationDetails(
  //       groupChannelId, groupChannelName, groupChannelDescription,
  //       importance: Importance.Max,
  //       priority: Priority.High,
  //       groupKey: groupKey);
  //   var secondNotificationPlatformSpecifics =
  //       NotificationDetails(secondNotificationAndroidSpecifics, null);
  //   await flutterLocalNotificationsPlugin.show(
  //       2,
  //       'Jeff Chang',
  //       'Please join us to celebrate the...',
  //       secondNotificationPlatformSpecifics);

  //   // create the summary notification to support older devices that pre-date Android 7.0 (API level 24).
  //   // this is required is regardless of which versions of Android your application is going to support
  //   var lines = List<String>();
  //   lines.add('Alex Faarborg  Check this out');
  //   lines.add('Jeff Chang    Launch Party');
  //   var inboxStyleInformation = InboxStyleInformation(lines,
  //       contentTitle: '2 messages', summaryText: 'janedoe@example.com');
  //   var androidPlatformChannelSpecifics = AndroidNotificationDetails(
  //       groupChannelId, groupChannelName, groupChannelDescription,
  //       styleInformation: inboxStyleInformation,
  //       groupKey: groupKey,
  //       setAsGroupSummary: true);
  //   var platformChannelSpecifics =
  //       NotificationDetails(androidPlatformChannelSpecifics, null);
  //   await flutterLocalNotificationsPlugin.show(
  //       3, 'Attention', 'Two messages', platformChannelSpecifics);
  // }
}

class ReceivedNotification {
  final int id;
  final String title;
  final String body;
  final String payload;
  final String url;
  final bool playsound;

  ReceivedNotification({
    @required this.id,
    @required this.title,
    this.body,
    this.url,
    this.payload,
    this.playsound
  });
}