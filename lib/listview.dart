import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:pain_suffering/main.dart';
import 'package:pain_suffering/message_model.dart';
import 'package:permission_handler/permission_handler.dart';

class Dashboard extends StatefulWidget {
  @override
  _dashboardState createState() => _dashboardState();
}

class _dashboardState extends State<Dashboard> {
  late Future<List<dynamic>> users; // Define a Future for storing users data

  static const eventChannel = EventChannel('app/native-code-event');
  static const MethodChannel channel = MethodChannel('app/native-code');

  Future<void> sendSms(String phoneNumber, String message) async {
    try {
      final result = await channel.invokeMethod('sendSms', {
        'phoneNumber': phoneNumber,
        'message': message,
      });
      print(result);
    } on PlatformException catch (e) {
      print("Failed to send SMS: '${e.message}'.");
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  

   void _startListeningForMessages()async  {
    var status = await Permission.sms.status;
    dynamic location = await _determinePosition();
    print("test");
    eventChannel.receiveBroadcastStream().listen(
      (message) {
        print(message);
        setState(() {
          MessageModel data = MessageModel.fromJson(jsonDecode(message));

          if(data.body == "hello")
          {
            sendSms(data.number, location.toString());
          }
        });
      },
      onError: (error) {
        print("Error receiving messages: $error");
      },
    );
  }

  // Method to fetch users from the server
  Future<List<dynamic>> fetchUsers() async {
    final response =
        await http.get(Uri.parse('http://192.168.1.29/servicephp/get.php'));

    if (response.statusCode == 200) {
      print(response.body);
      // Assuming the response is a list of users
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load users');
    }
  }

  Future<void> deleteLocation(String latitude, String longitude) async {
    final response = await http.post(
      Uri.parse(
          'http://192.168.1.29/servicephp/delete.php'), // Your delete endpoint
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'latitude': latitude, 'longitude': longitude}),
    );

    if (response.statusCode == 200) {
      print("Location deleted successfully");
      // Refresh the list after deletion
      setState(() {
        users = fetchUsers();
      });
    } else {
      print("Error deleting location: ${response.body}");
    }
  }

  @override
  void initState() {
    super.initState();
    _startListeningForMessages();
    users = Future.value([]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Button to fetch users
            ElevatedButton(
              onPressed: () {
                setState(() {
                  users = fetchUsers();
                });
              },
              child: Text('Fetch Users'),
            ),
            FutureBuilder<List<dynamic>>(
              future: users,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text('No users found');
                } else {
                  final userList = snapshot.data!;
                  return Expanded(
                    child: ListView.builder(
                      itemCount: userList.length,
                      itemBuilder: (context, index) {
                        final user = userList[index];
                        String details =
                            "${user['latitude']} ${user['longitude']}";
                        String info = "${user['pseudo']} || ${user['numero']}";
                        return ListTile(
                          title: Text(info),
                          subtitle: Text(details),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () {
                                  // Show a confirmation dialog before deletion
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Text('Confirm Deletion'),
                                        content: Text(
                                            'Do you want to delete this location?'),
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context)
                                                  .pop(); // Close the dialog
                                            },
                                            child: Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              deleteLocation(user['latitude'],
                                                  user['longitude']);
                                              Navigator.of(context)
                                                  .pop(); // Close the dialog
                                            },
                                            child: Text('Delete'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.sms),
                                onPressed: () {
                                  // Placeholder for SMS functionality
                                  print("SMS button pressed");
                                },
                              ),
                            ],
                          ),
                          onTap: () {
                            // Navigate to the LocationFormScreen with the location details
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LocationFormScreen(
                                  latitude: double.parse(user['latitude']),
                                  longitude: double.parse(user['longitude']),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
