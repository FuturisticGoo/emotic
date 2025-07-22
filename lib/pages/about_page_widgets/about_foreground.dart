import 'dart:async';

import 'package:emotic/widgets_common/show_message.dart';
import 'package:emotic/core/constants.dart';
import 'package:emotic/widgets_common/emotic_logo.dart';
import 'package:emotic/pages/about_page_widgets/frosted_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AboutForeground extends StatefulWidget {
  const AboutForeground({
    super.key,
  });

  @override
  State<AboutForeground> createState() => _AboutForegroundState();
}

class _AboutForegroundState extends State<AboutForeground> {
  int _tapCount = 0;
  String _emoticonText = "OwO";
  @override
  Widget build(BuildContext context) {
    return Center(
      child: FrostedCard(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmoticLogo(
                emoticonText: _emoticonText,
              ),
              IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Divider(),
                    ListTile(
                      onTap: () async {
                        await Clipboard.setData(
                            const ClipboardData(text: sourceLink));
                        if (context.mounted) {
                          showSnackBar(context, text: "Copied link");
                        }
                      },
                      title: const Text("Source Code"),
                      subtitle: const Text(sourceLink),
                    ),
                    ListTile(
                      onTap: () {},
                      title: const Text("License"),
                      subtitle: const Text("GPL-3.0"),
                    ),
                    ListTile(
                      onTap: () async {
                        if (_tapCount < 2) {
                          _tapCount++;
                        } else {
                          _tapCount = 0;
                          showSnackBar(context, text: "Back at ya!");
                          await Future.delayed(Durations.extralong2);
                          setState(() {
                            _emoticonText = "—wO";
                          });
                          await Future.delayed(Durations.medium4);
                          setState(() {
                            _emoticonText = "OwO";
                          });
                        }
                      },
                      title: const Text("Version"),
                      subtitle: Text(version.toString()),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
