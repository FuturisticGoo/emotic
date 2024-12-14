import 'package:flutter/material.dart';

class EmoticonsSearchBar extends StatefulWidget {
  final List<String> allTags;
  final TextEditingController controller;
  final void Function(String) onChange;
  const EmoticonsSearchBar({
    super.key,
    required this.allTags,
    required this.controller,
    required this.onChange,
  });

  @override
  State<EmoticonsSearchBar> createState() => _EmoticonsSearchBarState();
}

class _EmoticonsSearchBarState extends State<EmoticonsSearchBar> {
  bool showTagsSuggestion = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(
      () {
        widget.onChange(widget.controller.text);
      },
    );
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
            controller: widget.controller,
            autofocus: false,
            decoration: InputDecoration(
              hintText: "Search by tag",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(32),
              ),
              suffixIcon: widget.controller.text.trim().isEmpty
                  ? const Icon(Icons.search)
                  : IconButton(
                      onPressed: () {
                        widget.controller.text = "";
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
                              widget.controller.text = tag;
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
