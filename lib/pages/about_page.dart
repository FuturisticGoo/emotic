import 'dart:ui';

import 'package:emotic/core/constants.dart';
import 'package:emotic/core/open_root_scaffold_drawer.dart';
import 'package:emotic/widgets/show_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About"),
        leading: DrawerButton(
          onPressed: context.openRootScaffoldDrawer,
        ),
      ),
      body: const Center(
        child: Stack(
          children: [
            AboutForeground(),
          ],
        ),
      ),
    );
  }
}
// TODO: Add unnecessary animations and glitter to the about page
// because it's too boring now

// class MovingOwO extends StatefulWidget {
//   final Alignment beginAlignment;
//   final Alignment endAlignment;
//   final Duration startDelay;
//   const MovingOwO({
//     super.key,
//     required this.beginAlignment,
//     required this.endAlignment,
//     this.startDelay = Duration.zero,
//   });

//   @override
//   State<MovingOwO> createState() => _MovingOwOState();
// }

// class _MovingOwOState extends State<MovingOwO> with TickerProviderStateMixin {
//   late final AnimationController animationController = AnimationController(
//     duration: const Duration(seconds: 2),
//     vsync: this,
//   )..repeat(
//       reverse: true,
//     );
//   @override
//   void dispose() {
//     animationController.stop();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return AlignTransition(
//       alignment: Tween<Alignment>(
//         begin: widget.beginAlignment,
//         end: widget.endAlignment,
//       ).animate(
//         CurvedAnimation(
//           parent: animationController,
//           curve: Curves.easeInOut,
//         ),
//       ),
//       child: const Card.outlined(
//         child: Padding(
//           padding: EdgeInsets.all(8.0),
//           child: Text("OwO"),
//         ),
//       ),
//     );
//   }
// }

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

class FrostedCard extends StatelessWidget {
  final Widget child;
  const FrostedCard({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Card.outlined(
          clipBehavior: Clip.hardEdge,
          color: Theme.of(context).cardColor.withValues(alpha: 0.1),
          child: child,
        ),
      ),
    );
  }
}

class EmoticLogo extends StatelessWidget {
  const EmoticLogo({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "OwO",
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const Text("Emotic"),
        ],
      ),
    );
  }
}
