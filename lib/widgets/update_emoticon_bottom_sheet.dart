import 'package:emotic/core/emoticon.dart';
import 'package:flutter/material.dart';

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
    return BottomSheet(
      animationController: animationController,
      showDragHandle: true,
      enableDrag: false,
      onClosing: () {},
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text("${widget.isEditMode ? 'Modify' : 'Add'} emoticon"),
              const SizedBox(
                height: 20,
              ),
              TextField(
                controller: emoticonTextController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  label: Text("Emoticon"),
                ),
              ),
              const SizedBox(
                height: 30,
              ),
              Text("${widget.isEditMode ? 'Modify' : 'Add'} tags"),
              const SizedBox(
                height: 10,
              ),
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 5.0,
                    runSpacing: 5.0,
                    children: [...tagsSelection.keys, "+"]
                        .map(
                          (tag) => FilterChip(
                            label: Text(tag),
                            selected: tagsSelection[tag] ?? false,
                            onSelected: (selected) async {
                              if (tag == "+") {
                                final newTag = await addNewTag(context);
                                if (newTag != null) {
                                  setState(() {
                                    tagsSelection[newTag] = true;
                                  });
                                }
                              } else {
                                setState(() {
                                  tagsSelection[tag] = selected;
                                });
                              }
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const Spacer(
                flex: 1,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(
                    width: 20,
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop<Emoticon>(
                        context,
                        Emoticon(
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
                        ),
                      );
                    },
                    child: Text(widget.isEditMode ? "Save" : "Add"),
                  )
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> addNewTag(BuildContext context) {
    return showAdaptiveDialog<String?>(
      context: context,
      builder: (context) {
        String newTagText = "";
        return SimpleDialog(
          title: const Text("Add new tag"),
          contentPadding: const EdgeInsets.all(16.0),
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                label: Text("Tag"),
              ),
              onChanged: (value) {
                newTagText = value;
              },
            ),
            const SizedBox(
              height: 20,
            ),
            Builder(builder: (context) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        newTagText.trim().isEmpty ? null : newTagText.trim(),
                      );
                    },
                    child: const Text("Add"),
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
