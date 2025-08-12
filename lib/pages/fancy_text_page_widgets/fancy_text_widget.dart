import 'package:emotic/core/entities/fancy_text_transform.dart';
import 'package:emotic/widgets_common/show_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FancyTextWidget extends StatefulWidget {
  const FancyTextWidget({
    super.key,
    required this.fancyTextTransformer,
    required this.inputText,
    this.textSize,
  });

  final FancyTextTransform fancyTextTransformer;
  final String inputText;
  final int? textSize;

  @override
  State<FancyTextWidget> createState() => _FancyTextWidgetState();
}

class _FancyTextWidgetState extends State<FancyTextWidget> {
  final TextEditingController _textEditingController = TextEditingController();

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      minLines: 1,
      maxLines: 3,
      controller: _textEditingController
        ..text = widget.fancyTextTransformer.getTransformedText(
          text: widget.inputText.isEmpty
              ? "Never gonna give you up"
              : widget.inputText,
        ),
      decoration: InputDecoration(
        suffixIcon: IconButton(
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(
                text: _textEditingController.text,
              ),
            );
            if (context.mounted) {
              showSnackBar(context, text: "Copied text!");
            }
          },
          icon: Icon(
            Icons.copy,
          ),
        ),
        labelText: widget.fancyTextTransformer.textTransformerName,
        border: OutlineInputBorder(),
      ),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontSize: widget.textSize?.toDouble(),
          ),
      readOnly: true,
    );
  }
}
