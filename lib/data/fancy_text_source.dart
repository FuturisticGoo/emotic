import 'package:emotic/core/entities/fancy_text_transform.dart';
import 'package:emotic/core/helper_functions.dart';

abstract class FancyTextSource {
  Future<List<FancyTextTransform>> getFancyTextTransforms();
}

class FancyTextSourceHardcoded extends FancyTextSource {
  @override
  Future<List<FancyTextTransform>> getFancyTextTransforms() async {
    return _hardcodedTransforms;
  }
}

class _UppercaseTransform extends FancyTextTransform {
  @override
  String get textTransformerName => "Uppercase";
  @override
  String getTransformedText({required String text}) {
    return text.toUpperCase();
  }
}

class _LowercaseTransform extends FancyTextTransform {
  @override
  String get textTransformerName => "Lowercase";
  @override
  String getTransformedText({required String text}) {
    return text.toLowerCase();
  }
}

class _AlternativeCaseTransform extends FancyTextTransform {
  @override
  String get textTransformerName => "Alternative case";
  @override
  String getTransformedText({required String text}) {
    final outStringBuffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i % 2 == 0) {
        outStringBuffer.write(text[i].toLowerCase());
      } else {
        outStringBuffer.write(text[i].toUpperCase());
      }
    }
    return outStringBuffer.toString();
  }
}

class _StrikeThroughTransform extends FancyTextTransform {
  @override
  String get textTransformerName => "Strikethrough";
  @override
  String getTransformedText({required String text}) {
    final outStringBuffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      outStringBuffer.write(text[i]);
      outStringBuffer.write("\u0336");
    }
    return outStringBuffer.toString();
  }
}

class _UpsideDownTransform extends FancyTextTransform {
  @override
  String get textTransformerName => "Upside down";
  @override
  String getTransformedText({required String text}) {
    final tempTransform = SimpleMappingTextTranform(
        textTransformerName: "Upside down",
        fromText: "$_lowerCaseEnglish.?\"'!^&`_",
        toText: "ɐqɔpǝɟƃɥᴉɾʞlɯuodbɹsʇnʌʍxʎz˙¿,,¡v⅋,‾");
    final outStringBuffer = StringBuffer();
    for (int i = text.length - 1; i >= 0; i--) {
      outStringBuffer.write(
        tempTransform.getTransformedText(
          text: text[i].toLowerCase(),
        ),
      );
    }
    return outStringBuffer.toString();
  }
}

class _CursedTransform extends FancyTextTransform {
  @override
  String get textTransformerName => "Cursed Text";
  @override
  String getTransformedText({required String text}) {
    final cursedLevel = 3;
    final outStringBuffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final diacritics = getRandomChoice(
        items: _cursedDiacritics,
        n: cursedLevel,
        withReplacement: false,
      );
      outStringBuffer.write(text[i]);
      outStringBuffer.writeAll(diacritics);
    }
    return outStringBuffer.toString();
  }
}

const _lowerCaseEnglish = "abcdefghijklmnopqrstuvwxyz";
const _upperCaseEnglish = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const _numbers = "0123456789";
final _symbols = r"""`~!@#$%^&*()-_+={}[]|\:;"'<>,.?/""";
const _englishCharsAndNumbers = "$_lowerCaseEnglish$_upperCaseEnglish$_numbers";
final _hardcodedTransforms = <FancyTextTransform>[
  SimpleMappingTextTranform(
    textTransformerName: "Superscript/Tiny text",
    fromText: "$_englishCharsAndNumbers.,",
    toText: "ᵃᵇᶜᵈᵉᶠᵍʰⁱʲᵏˡᵐⁿᵒᵖ𐞥ʳˢᵗᵘᵛʷˣʸᶻ"
        "ᴬᴮꟲᴰᴱꟳᴳᴴᴵᴶᴷᴸᴹᴺᴼᴾꟴᴿˢᵀᵁⱽᵂˣʸᶻ"
        "⁰¹²³⁴⁵⁶⁷⁸⁹·⸴",
  ),
  SimpleMappingTextTranform(
    textTransformerName: "Small caps",
    fromText: _lowerCaseEnglish,
    toText: "ᴀʙᴄᴅᴇꜰɢʜɪᴊᴋʟᴍɴᴏᴘQʀꜱᴛᴜᴠᴡxʏᴢ",
  ),
  SimpleMappingTextTranform(
    textTransformerName: "Monospace",
    fromText: _englishCharsAndNumbers,
    toText: "𝚊𝚋𝚌𝚍𝚎𝚏𝚐𝚑𝚒𝚓𝚔𝚕𝚖𝚗𝚘𝚙𝚚𝚛𝚜𝚝𝚞𝚟𝚠𝚡𝚢𝚣"
        "𝙰𝙱𝙲𝙳𝙴𝙵𝙶𝙷𝙸𝙹𝙺𝙻𝙼𝙽𝙾𝙿𝚀𝚁𝚂𝚃𝚄𝚅𝚆𝚇𝚈𝚉"
        "𝟶𝟷𝟸𝟹𝟺𝟻𝟼𝟽𝟾𝟿",
  ),
  _LowercaseTransform(),
  _UppercaseTransform(),
  _AlternativeCaseTransform(),
  SimpleMappingTextTranform(
    textTransformerName: "Full width/Vaporwave",
    fromText: "$_englishCharsAndNumbers$_symbols ",
    toText: "ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ"
        "ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ"
        "０１２３４５６７８９"
        "｀～！＠＃＄％＾＆＊（）－＿＋＝｛｝［］｜＼：；＂＇＜＞，．？／ ",
  ),
  SimpleMappingTextTranform(
    textTransformerName: "Cursive",
    fromText: "$_lowerCaseEnglish$_upperCaseEnglish",
    toText: "𝒶𝒷𝒸𝒹ℯ𝒻ℊ𝒽𝒾𝒿𝓀𝓁𝓂𝓃ℴ𝓅𝓆𝓇𝓈𝓉𝓊𝓋𝓌𝓍𝓎𝓏"
        "𝒜ℬ𝒞𝒟ℰℱ𝒢ℋℐ𝒥𝒦ℒℳ𝒩𝒪𝒫𝒬ℛ𝒮𝒯𝒰𝒱𝒲𝒳𝒴𝒵",
  ),
  SimpleMappingTextTranform(
    textTransformerName: "Outlined Circle",
    fromText: _englishCharsAndNumbers,
    toText: "ⓐⓑⓒⓓⓔⓕⓖⓗⓘⓙⓚⓛⓜⓝⓞⓟⓠⓡⓢⓣⓤⓥⓦⓧⓨⓩ"
        "ⒶⒷⒸⒹⒺⒻⒼⒽⒾⒿⓀⓁⓂⓃⓄⓅⓆⓇⓈⓉⓊⓋⓌⓍⓎⓏ"
        "⓪①②③④⑤⑥⑦⑧⑨",
  ),
  SimpleMappingTextTranform(
    textTransformerName: "Filled Circle",
    fromText: _englishCharsAndNumbers,
    toText: "${'🅐🅑🅒🅓🅔🅕🅖🅗🅘🅙🅚🅛🅜🅝🅞🅟🅠🅡🅢🅣🅤🅥🅦🅧🅨🅩' * 2}"
        "⓿❶❷❸❹❺❻❼❽❾",
  ),
  SimpleMappingTextTranform(
    textTransformerName: "Blackboard bold",
    fromText: _englishCharsAndNumbers,
    toText: "𝕒𝕓𝕔𝕕𝕖𝕗𝕘𝕙𝕚𝕛𝕜𝕝𝕞𝕟𝕠𝕡𝕢𝕣𝕤𝕥𝕦𝕧𝕨𝕩𝕪𝕫"
        "𝔸𝔹ℂ𝔻𝔼𝔽𝔾ℍ𝕀𝕁𝕂𝕃𝕄ℕ𝕆ℙℚℝ𝕊𝕋𝕌𝕍𝕎𝕏𝕐ℤ"
        "𝟘𝟙𝟚𝟛𝟜𝟝𝟞𝟟𝟠𝟡",
  ),
  SimpleMappingTextTranform(
    textTransformerName: "Squared",
    fromText: "$_lowerCaseEnglish$_upperCaseEnglish",
    toText: "🄰🄱🄲🄳🄴🄵🄶🄷🄸🄹🄺🄻🄼🄽🄾🄿🅀🅁🅂🅃🅄🅅🅆🅇🅈🅉" * 2,
  ),
  _StrikeThroughTransform(),
  _UpsideDownTransform(),
  _CursedTransform(),
];

const _cursedDiacritics = [
  '̀',
  '́',
  '̂',
  '̃',
  '̄',
  '̅',
  '̆',
  '̇',
  '̈',
  '̉',
  '̊',
  '̋',
  '̌',
  '̍',
  '̎',
  '̏',
  '̐',
  '̑',
  '̒',
  '̓',
  '̔',
  '̕',
  '̖',
  '̗',
  '̘',
  '̙',
  '̚',
  '̛',
  '̜',
  '̝',
  '̞',
  '̟',
  '̠',
  '̡',
  '̢',
  '̣',
  '̤',
  '̥',
  '̦',
  '̧',
  '̨',
  '̩',
  '̪',
  '̫',
  '̬',
  '̭',
  '̮',
  '̯',
  '̰',
  '̱',
  '̲',
  '̳',
  '̴',
  '̵',
  '̶',
  '̷',
  '̸',
  '̹',
  '̺',
  '̻',
  '̼',
  '̽',
  '̾',
  '̿',
  '̀',
  '́',
  '͂',
  '̓',
  '̈́',
  'ͅ',
  '͆',
  '͇',
  '͈',
  '͉',
  '͊',
  '͋',
  '͌',
  '͍',
  '͎',
  '͏',
  '͐',
  '͑',
  '͒',
  '͓',
  '͔',
  '͕',
  '͖',
  '͗',
  '͘',
  '͙',
  '͚',
  '͛',
  '͜',
  '͝',
  '͞',
  '͟',
  '͠',
  '͡',
  '͢',
  'ͣ',
  'ͤ',
  'ͥ',
  'ͦ',
  'ͧ',
  'ͨ',
  'ͩ',
  'ͪ',
  'ͫ',
  'ͬ',
  'ͭ',
  'ͮ',
  'ͯ',
  '᪰',
  '᪱',
  '᪲',
  '᪳',
  '᪴',
  '᪵',
  '᪶',
  '᪷',
  '᪸',
  '᪹',
  '᪺',
  '᪻',
  '᪼',
  '᪽',
  '',
  '᷀',
  '᷁',
  '᷂',
  '᷃',
  '᷄',
  '᷅',
  '᷆',
  '᷇',
  '᷈',
  '᷉',
  '᷊',
  '᷋',
  '᷌',
  '᷍',
  '᷎',
  '᷏',
  '᷐',
  '᷑',
  '᷒',
  'ᷓ',
  'ᷔ',
  'ᷕ',
  'ᷖ',
  'ᷗ',
  'ᷘ',
  'ᷙ',
  'ᷚ',
  'ᷛ',
  'ᷜ',
  'ᷝ',
  'ᷞ',
  'ᷟ',
  'ᷠ',
  'ᷡ',
  'ᷢ',
  'ᷣ',
  'ᷤ',
  'ᷥ',
  'ᷦ',
  'ᷧ',
  'ᷨ',
  'ᷩ',
  'ᷪ',
  'ᷫ',
  'ᷬ',
  'ᷭ',
  'ᷮ',
  'ᷯ',
  'ᷰ',
  'ᷱ',
  'ᷲ',
  'ᷳ',
  'ᷴ',
  '᷵',
  '᷻',
  '᷼',
  '᷽',
  '᷾',
  '᷿',
];
