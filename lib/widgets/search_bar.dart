import 'package:emotic/cubit/emoticons_listing_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EmoticonsSearchBar extends StatefulWidget {
  final List<String> allTags;
  const EmoticonsSearchBar({
    super.key,
    required this.allTags,
  });

  @override
  State<EmoticonsSearchBar> createState() => _EmoticonsSearchBarState();
}

class _EmoticonsSearchBarState extends State<EmoticonsSearchBar> {
  bool showTagsSuggestion = false;
  late TextEditingController controller;
  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
    controller.addListener(
      () {
        context.read<EmoticonsListingCubit>().searchEmoticons(
              searchTerm: controller.text,
            );
      },
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (event) {
        setState(() {
          showTagsSuggestion = false;
        });
      },
      child: Column(
        children: [
          TextField(
            controller: controller,
            autofocus: false,
            decoration: InputDecoration(
              hintText: "Search by tag",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(32),
              ),
              suffixIcon: controller.text.trim().isEmpty
                  ? const Icon(Icons.search)
                  : IconButton(
                      onPressed: () {
                        controller.text = "";
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
            onTap: () {
              setState(() {
                showTagsSuggestion = true;
              });
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 100),
            child: SizedBox(
              height: showTagsSuggestion ? null : 0,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: widget.allTags.map(
                        (tag) {
                          return InkWell(
                            child: Card.outlined(
                              clipBehavior: Clip.hardEdge,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(tag),
                              ),
                            ),
                            onTap: () {
                              controller.text = tag;
                            },
                          );
                        },
                      ).toList(),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Divider()
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
