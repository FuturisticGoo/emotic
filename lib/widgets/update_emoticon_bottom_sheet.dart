import 'package:emotic/core/emoticon.dart';
import 'package:emotic/widgets/add_tag_helper.dart';
import 'package:flutter/material.dart';

sealed class BottomSheetResult {
  final Emoticon emoticon;
  const BottomSheetResult({
    required this.emoticon,
  });
}

class DeleteEmoticon extends BottomSheetResult {
  const DeleteEmoticon({required super.emoticon});
}

class UpdateEmoticon extends BottomSheetResult {
  final Emoticon newEmoticon;
  const UpdateEmoticon({
    required super.emoticon,
    required this.newEmoticon,
  });
}

class AddEmoticon extends BottomSheetResult {
  const AddEmoticon({required super.emoticon});
}

class TagClicked extends BottomSheetResult {
  final String tag;
  const TagClicked({
    required super.emoticon,
    required this.tag,
  });
}

class UpdateEmoticonBottomSheet extends StatefulWidget {
  const UpdateEmoticonBottomSheet({
    super.key,
    required this.allTags,
    this.isEditMode = false,
    this.emoticon = const Emoticon(
      id: null,
      text: "",
      emoticonTags: [],
    ),
  });
  final bool isEditMode;
  final Emoticon emoticon;
  final List<String> allTags;

  @override
  State<UpdateEmoticonBottomSheet> createState() =>
      _UpdateEmoticonBottomSheetState();
}

class _UpdateEmoticonBottomSheetState extends State<UpdateEmoticonBottomSheet>
    with SingleTickerProviderStateMixin {
  late final TextEditingController emoticonTextController;
  late final AnimationController animationController;
  bool readOnlyMode = true;
  Map<String, bool> tagsSelection = {};
  @override
  void initState() {
    super.initState();
    emoticonTextController = TextEditingController(
      text: widget.emoticon.text,
    );
    animationController = AnimationController(vsync: this);
    tagsSelection = Map.fromEntries(
      widget.allTags.map(
        (tag) => MapEntry(
          tag,
          widget.emoticon.emoticonTags.contains(tag),
        ),
      ),
    );
  }

  @override
  void dispose() {
    animationController.dispose();
    emoticonTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isSmallScreen = screenHeight < 640;
    return BottomSheet(
      animationController: animationController,
      showDragHandle: true,
      enableDrag: false,
      constraints: BoxConstraints.expand(
        height: isSmallScreen ? screenHeight : screenHeight * 0.7,
      ),
      onClosing: () {},
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                switch ((widget.isEditMode, readOnlyMode)) {
                  (true, true) => "Emoticon",
                  (true, false) => "Modify emoticon",
                  (false, _) => "Add emoticon"
                },
              ),
              SizedBox(
                height: isSmallScreen ? 10 : 20,
              ),
              TextField(
                readOnly: readOnlyMode,
                controller: emoticonTextController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  label: Text("Emoticon"),
                ),
              ),
              SizedBox(
                height: isSmallScreen ? 15 : 30,
              ),
              Text(
                switch ((widget.isEditMode, readOnlyMode)) {
                  (true, true) => "Tags",
                  (true, false) => "Modify tags",
                  (false, _) => "Add tags"
                },
              ),
              const SizedBox(
                height: 10,
              ),
              TagsSelection(
                isSmallScreen: isSmallScreen,
                tagsSelection: readOnlyMode
                    ? tagsSelection
                    : {
                        ...tagsSelection,
                        "+": false,
                      },
                onSelect: (tag, selected) async {
                  if (tag == "+") {
                    final newTag = await addNewTag(context);
                    if (newTag != null) {
                      setState(() {
                        tagsSelection[newTag] = true;
                      });
                    }
                  } else if (readOnlyMode) {
                    Navigator.pop<BottomSheetResult>(
                      context,
                      TagClicked(
                        emoticon: widget.emoticon,
                        tag: tag,
                      ),
                    );
                  } else {
                    setState(() {
                      tagsSelection[tag] = selected;
                    });
                  }
                },
              ),
              const Spacer(
                flex: 1,
              ),
              Row(
                // mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ...switch ((widget.isEditMode, readOnlyMode)) {
                    (true, true) => [
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              readOnlyMode = false;
                            });
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text("Edit"),
                        ),
                      ],
                    (true, false) => [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.only(),
                          ),
                          onPressed: () async {
                            if (await confirmDeletionDialog(context) == true &&
                                context.mounted) {
                              Navigator.pop<BottomSheetResult>(
                                context,
                                DeleteEmoticon(
                                  emoticon: widget.emoticon,
                                ),
                              );
                            }
                          },
                          child: Icon(
                            Icons.delete,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const Spacer(
                          flex: 10,
                        ),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text("Cancel"),
                        ),
                        const Flexible(
                          flex: 1,
                          child: SizedBox(
                            width: 20,
                          ),
                        ),
                        FilledButton(
                          onPressed: () {
                            final newEmoticon = Emoticon(
                              id: widget.emoticon.id,
                              text: emoticonTextController.text,
                              emoticonTags: tagsSelection.entries
                                  .where(
                                    (tag) => tag.value,
                                  )
                                  .map(
                                    (e) => e.key,
                                  )
                                  .toList(),
                            );

                            Navigator.pop<BottomSheetResult>(
                                context,
                                UpdateEmoticon(
                                  emoticon: widget.emoticon,
                                  newEmoticon: newEmoticon,
                                ));
                          },
                          child: const Text("Save"),
                        )
                      ],
                    (false, _) => [
                        const Spacer(
                          flex: 10,
                        ),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text("Cancel"),
                        ),
                        const Flexible(
                          flex: 1,
                          child: SizedBox(
                            width: 20,
                          ),
                        ),
                        FilledButton(
                          onPressed: () {
                            final newEmoticon = Emoticon(
                              id: widget.emoticon.id,
                              text: emoticonTextController.text,
                              emoticonTags: tagsSelection.entries
                                  .where(
                                    (tag) => tag.value,
                                  )
                                  .map(
                                    (e) => e.key,
                                  )
                                  .toList(),
                            );

                            Navigator.pop<BottomSheetResult>(
                              context,
                              AddEmoticon(
                                emoticon: newEmoticon,
                              ),
                            );
                          },
                          child: const Text("Add"),
                        )
                      ]
                  },
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> confirmDeletionDialog(BuildContext context) {
    return showAdaptiveDialog<bool?>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text("Delete emoticon?"),
          contentPadding: const EdgeInsets.all(16.0),
          children: [
            const SizedBox(
              height: 20,
            ),
            Builder(builder: (context) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context, false);
                    },
                    child: const Text("No"),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        true,
                      );
                    },
                    child: const Text("Yes"),
                  ),
                ],
              );
            })
          ],
        );
      },
    );
  }
}

class TagsSelection extends StatefulWidget {
  final bool isSmallScreen;
  final Map<String, bool> tagsSelection;
  final void Function(String tag, bool selected) onSelect;
  const TagsSelection({
    super.key,
    required this.isSmallScreen,
    required this.tagsSelection,
    required this.onSelect,
  });

  @override
  State<TagsSelection> createState() => _TagsSelectionState();
}

class _TagsSelectionState extends State<TagsSelection> {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: widget.isSmallScreen ? 6 : 4,
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 5.0,
          runSpacing: 5.0,
          children: widget.tagsSelection.keys
              .map(
                (tag) => FilterChip(
                  label: Text(tag),
                  selected: widget.tagsSelection[tag] ?? false,
                  onSelected: (selected) => widget.onSelect(tag, selected),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
