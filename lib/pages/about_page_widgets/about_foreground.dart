import 'package:emotic/widgets_common/show_message.dart';
import 'package:emotic/core/constants.dart';
import 'package:emotic/widgets_common/emotic_logo.dart';
import 'package:emotic/pages/about_page_widgets/frosted_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AboutForeground extends StatelessWidget {
  const AboutForeground({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FrostedCard(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EmoticLogo(),
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
                      onTap: () {},
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
