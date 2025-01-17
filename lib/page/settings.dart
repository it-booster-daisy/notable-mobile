import 'dart:io';

import 'package:directory_picker/directory_picker.dart';
import 'package:flutter/material.dart';
import 'package:notable/provider/theme.dart';
import 'package:notable/store/notes.dart';
import 'package:path_provider/path_provider.dart';
import 'package:preferences/preferences.dart';
import 'package:preferences/radio_preference.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  final NotesStore store;
  SettingsPage(this.store);
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  NotesStore get store => widget.store;
  @override
  void initState() {
    PrefService.setDefaultValues({
      'sync': '',
      'sync_webdav_host': '',
      'sync_webdav_path': '',
      'sync_webdav_username': '',
      'sync_webdav_password': '',
      'theme': 'light',
      'search_content': true
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(children: <Widget>[
        PreferenceTitle('Theme'),
        RadioPreference(
          'Light',
          'light',
          'theme',
          isDefault: true,
          onSelect: () {
            Provider.of<ThemeNotifier>(context).updateTheme('light');
          },
        ),
        RadioPreference(
          'Dark',
          'dark',
          'theme',
          onSelect: () {
            Provider.of<ThemeNotifier>(context).updateTheme('dark');
          },
        ),
        ListTile(
          title: Text('Accent Color'),
          trailing: Padding(
            padding: const EdgeInsets.only(right: 9, left: 9),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(),
                color: Color(PrefService.getInt('theme_color') ?? 0xfff5b746),
              ),
              child: SizedBox(
                width: 28,
                height: 28,
              ),
            ),
          ),
          onTap: () async {
            Color color = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                      title: Text('Select accent color'),
                      content: Container(
                        child: GridView.count(
                          crossAxisCount: 5,
                          children: [
                            for (Color color in [
                              Color(0xfff5b746),
                              ...Colors.primaries,
                              ...Colors.accents,
                            ])
                              InkWell(
                                child: Container(
                                  margin: const EdgeInsets.all(5),
                                  color: color,
                                ),
                                onTap: () {
                                  Navigator.of(context).pop(color);
                                },
                              )
                          ],
                        ),
                        width: MediaQuery.of(context).size.width * .7,
                      ),
                      actions: <Widget>[
                        FlatButton(
                          child: Text('Cancel'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ));
            if (color != null) {
              PrefService.setInt('theme_color', color.value);
              Provider.of<ThemeNotifier>(context).accentColor = color;
            }
          },
        ),
        if (Platform.isAndroid) ...[
          PreferenceTitle('Data Directory'),
          SwitchPreference(
            'Use external storage',
            'notable_external_directory_enabled',
            onChange: () async {
              if (PrefService.getString('notable_external_directory') == null) {
                PrefService.setString('notable_external_directory',
                    (await getExternalStorageDirectory()).path);
              }

              await store.listNotes();
              await store.filterAndSortNotes();
              await store.updateTagList();

              if (mounted) setState(() {});
            },
          ),
          PreferenceHider([
            ListTile(
              title: Text('Location'),
              subtitle: Text(
                PrefService.getString('notable_external_directory') ?? '',
              ),
              onTap: () async {
                String path =
                    PrefService.getString('notable_external_directory');
                Directory newDirectory = await DirectoryPicker.pick(
                    allowFolderCreation: true,
                    context: context,
                    rootDirectory: path != null
                        ? Directory(path)
                        : (await getExternalStorageDirectory()));
                print(newDirectory);
                if (newDirectory != null) {
                  PrefService.setString(
                      'notable_external_directory', newDirectory.path);

                  await store.listNotes();
                  await store.filterAndSortNotes();
                  await store.updateTagList();
                  setState(() {});
                }
              },
            ),
          ], '!notable_external_directory_enabled'),
        ],
        PreferenceTitle('Search'),
        SwitchPreference(
          'Search content of notes',
          'search_content',
        ),
        PreferenceTitle('Sync'),
        RadioPreference(
          'No Sync',
          '',
          'sync',
          isDefault: true,
          onSelect: () {
            setState(() {
              store.syncMethod = '';
            });
          },
        ),
        RadioPreference(
          'WebDav Sync',
          'webdav',
          'sync',
          onSelect: () {
            setState(() {
              store.syncMethod = 'webdav';
            });
          },
        ),
        if (store.syncMethod == 'webdav')
          Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Warning: Webdav Sync isn\'t stable! Please do NOT use it for important data or accounts!',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              TextFieldPreference(
                'Host',
                'sync_webdav_host',
                hintText: 'mynextcloud.tld',
              ),
              TextFieldPreference(
                'Path',
                'sync_webdav_path',
                hintText: 'remote.php/webdav/',
              ),
              TextFieldPreference('Username', 'sync_webdav_username'),
              TextFieldPreference(
                'Password',
                'sync_webdav_password',
                obscureText: true,
              ),
            ],
          ),
        PreferenceTitle('More'),
        ListTile(
          title: Text('Recreate tutorial notes'),
          onTap: () async {
            if (await showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                          title: Text(
                              'Do you want to recreate the tutorial notes and attachments?'),
                          actions: <Widget>[
                            FlatButton(
                              child: Text('Cancel'),
                              onPressed: () {
                                Navigator.of(context).pop(false);
                              },
                            ),
                            FlatButton(
                              child: Text('Recreate'),
                              onPressed: () {
                                Navigator.of(context).pop(true);
                              },
                            )
                          ],
                        )) ??
                false) {
              await store.createTutorialNotes();
              await store.createTutorialAttachments();
              await store.listNotes();
              await store.filterAndSortNotes();
              await store.updateTagList();
            }
          },
        ),
      ]),
    );
  }
}
