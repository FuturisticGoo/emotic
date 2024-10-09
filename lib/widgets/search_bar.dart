import 'package:emotic/cubit/emoticons_listing_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EmoticonsSearchBar extends StatefulWidget {
  const EmoticonsSearchBar({
    super.key,
  });

  @override
  State<EmoticonsSearchBar> createState() => _EmoticonsSearchBarState();
}

class _EmoticonsSearchBarState extends State<EmoticonsSearchBar> {
  bool showTagsSuggestion = false;
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
            autofocus: false,
            decoration: InputDecoration(
              hintText: "Search by tag",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(32),
              ),
              suffixIcon: const Icon(Icons.search),
            ),
            onTap: () {
              setState(() {
                showTagsSuggestion = true;
              });
            },
            onChanged: (value) {
              context
                  .read<EmoticonsListingCubit>()
                  .searchEmoticons(searchTerm: value);
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
                      children: List.generate(
                        10,
                        (index) {
                          return Card.outlined(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text("Tag #$index"),
                            ),
                          );
                        },
                      ),
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
