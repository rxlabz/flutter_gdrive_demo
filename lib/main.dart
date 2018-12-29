import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:http/http.dart' show BaseRequest, Response, StreamedResponse;
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';

/*

https://qiita.com/aoinakanishi/items/6ff8222847fcf934a64a

scopes : https://developers.google.com/identity/protocols/googlescopes
Drive API : https://developers.google.com/drive/
 */

GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: [
    'email',
    'https://www.googleapis.com/auth/drive.file',
  ],
);

void main() => runApp(DriveApp());

class DriveApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DriveScreen(),
    );
  }
}

class DriveScreen extends StatefulWidget {
  @override
  DriveScreenState createState() {
    return new DriveScreenState();
  }
}

class DriveScreenState extends State<DriveScreen> {
  GoogleSignInAccount account;
  DriveApi api;

  GlobalKey<ScaffoldState> _sKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _sKey,
      appBar: AppBar(
        title: Text('Flutter to drive'),
        actions: account == null
            ? []
            : <Widget>[
                IconButton(icon: Icon(Icons.exit_to_app), onPressed: logout)
              ],
      ),
      body: Center(
        child: account == null
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: RaisedButton(child: Text('Login'), onPressed: login),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundImage:
                              NetworkImage(account.photoUrl, scale: 0.3),
                          backgroundColor: Colors.yellow,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(account.displayName),
                      )
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: RaisedButton(
                        child: Text('save random file'), onPressed: toDrive),
                  ),
                  Expanded(
                    child: FutureBuilder(
                        initialData: null,
                        future: api.files.list(),
                        builder: (context, AsyncSnapshot snapshot) {
                          if (snapshot.hasData) {
                            return ListView(
                              children: (snapshot.data as FileList)
                                  .files
                                  .map((f) => ListTile(
                                        title: Text(f.name),
                                      ))
                                  .toList(),
                            );
                          }
                          return SizedBox();
                        }),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> login() async {
    try {
      account = await _googleSignIn.signIn();
      final client =
          GoogleHttpClient(await _googleSignIn.currentUser.authHeaders);
      api = DriveApi(client);
    } catch (error) {
      print('DriveScreen.login.ERROR... $error');
    }
    setState(() {});
  }

  void listFiles() async {
    final files = await api.files.list();
    print('DriveScreenState.listFiles... $files');
  }

  void toDrive() async {
    final filename = 'file-${DateTime.now().millisecondsSinceEpoch}.txt';

    final gFile = File();
    gFile.name = filename;

    final dir = await getApplicationDocumentsDirectory();
    final f = io.File('${dir.path}/$filename');
    await f.create();
    await f.writeAsString('$filename');

    api.files
        .create(gFile, uploadMedia: Media(f.openRead(), f.lengthSync()))
        .then((file) => _sKey.currentState.showSnackBar(
            SnackBar(content: Text('File saved => id : ${file.id}'))));
  }

  void logout() {
    _googleSignIn.signOut();
  }
}

class GoogleHttpClient extends IOClient {
  Map<String, String> _headers;

  GoogleHttpClient(this._headers) : super();

  @override
  Future<StreamedResponse> send(BaseRequest request) =>
      super.send(request..headers.addAll(_headers));

  @override
  Future<Response> head(Object url, {Map<String, String> headers}) =>
      super.head(url, headers: headers..addAll(_headers));
}
