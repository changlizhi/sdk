// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'dart:io';

import 'dart:isolate';

import 'package:yaml/yaml.dart' show loadYaml;

import 'package:dart_style/dart_style.dart' show DartFormatter;

import "package:front_end/src/fasta/severity.dart" show severityEnumNames;

main(List<String> arguments) async {
  var port = new ReceivePort();
  await new File.fromUri(await computeGeneratedFile())
      .writeAsString(await generateMessagesFile(), flush: true);
  port.close();
}

Future<Uri> computeGeneratedFile() {
  return Isolate.resolvePackageUri(
      Uri.parse('package:front_end/src/fasta/fasta_codes_generated.dart'));
}

Future<String> generateMessagesFile() async {
  Uri messagesFile = Platform.script.resolve("../../messages.yaml");
  Map<dynamic, dynamic> yaml =
      loadYaml(await new File.fromUri(messagesFile).readAsStringSync());
  StringBuffer sb = new StringBuffer();

  sb.writeln("""
// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// NOTE: THIS FILE IS GENERATED. DO NOT EDIT.
//
// Instead modify 'pkg/front_end/messages.yaml' and run
// 'pkg/front_end/tool/fasta generate-messages' to update.

part of fasta.codes;
""");

  bool hasError = false;
  int largestIndex = 0;
  final indexNameMap = new Map<int, String>();

  List<String> keys = yaml.keys.cast<String>().toList()..sort();
  for (String name in keys) {
    var description = yaml[name];
    while (description is String) {
      description = yaml[description];
    }
    Map<dynamic, dynamic> map = description;
    if (map == null) {
      throw "No 'template:' in key $name.";
    }
    var index = map['index'];
    if (index != null) {
      if (index is! int || index < 1) {
        print('Error: Expected positive int for "index:" field in $name,'
            ' but found $index');
        hasError = true;
        index = -1;
        // Continue looking for other problems.
      } else {
        String otherName = indexNameMap[index];
        if (otherName != null) {
          print('Error: The "index:" field must be unique, '
              'but is the same for $otherName and $name');
          hasError = true;
          // Continue looking for other problems.
        } else {
          indexNameMap[index] = name;
          if (largestIndex < index) {
            largestIndex = index;
          }
        }
      }
    }
    sb.writeln(compileTemplate(name, index, map['template'], map['tip'],
        map['analyzerCode'], map['severity']));
  }
  if (largestIndex > indexNameMap.length) {
    print('Error: The "index:" fields should be sequential starting with 1.');
    hasError = true;
    // Fall through to print more information.
  }
  if (hasError) {
    exitCode = 1;
    print('The largest index is $largestIndex');
    final sortedIndices = indexNameMap.keys.toList()..sort();
    int nextAvailableIndex = largestIndex + 1;
    for (int index = 1; index <= sortedIndices.length; ++index) {
      if (sortedIndices[index - 1] != index) {
        nextAvailableIndex = index;
        break;
      }
    }
    print('The next available index is ${nextAvailableIndex}');
    return '';
  }

  return new DartFormatter().format("$sb");
}

final RegExp placeholderPattern =
    new RegExp("#\([-a-zA-Z0-9_]+\)(?:%\([0-9]*\)\.\([0-9]+\))?");

String compileTemplate(String name, int index, String template, String tip,
    String analyzerCode, String severity) {
  if (template == null) {
    print('Error: missing template for message: $name');
    exitCode = 1;
    return '';
  }
  // Remove trailing whitespace. This is necessary for templates defined with
  // `|` (verbatim) as they always contain a trailing newline that we don't
  // want.
  template = template.trimRight();
  var parameters = new Set<String>();
  var conversions = new Set<String>();
  var arguments = new Set<String>();
  bool hasNameSystem = false;
  void ensureNameSystem() {
    if (hasNameSystem) return;
    conversions.add(r"""
NameSystem nameSystem = new NameSystem();
StringBuffer buffer;""");
    hasNameSystem = true;
  }

  for (Match match in placeholderPattern.allMatches("$template${tip ?? ''}")) {
    String name = match[1];
    String padding = match[2];
    String fractionDigits = match[3];

    String format(String name) {
      String conversion;
      if (fractionDigits == null) {
        conversion = "'\$$name'";
      } else {
        conversion = "$name.toStringAsFixed($fractionDigits)";
      }
      if (padding.isNotEmpty) {
        if (padding.startsWith("0")) {
          conversion += ".padLeft(${int.parse(padding)}, '0')";
        } else {
          conversion += ".padLeft(${int.parse(padding)})";
        }
      }
      return conversion;
    }

    switch (name) {
      case "character":
        parameters.add("String character");
        arguments.add("'character': character");
        break;

      case "unicode":
        // Write unicode value using at least four (but otherwise no more than
        // necessary) hex digits, using uppercase letters.
        // http://www.unicode.org/versions/Unicode10.0.0/appA.pdf
        parameters.add("int codePoint");
        conversions.add("String unicode = \"U+\${codePoint.toRadixString(16)"
            ".toUpperCase().padLeft(4, '0')}\";");
        arguments.add("'codePoint': codePoint");
        break;

      case "name":
        parameters.add("String name");
        arguments.add("'name': name");
        break;

      case "name2":
        parameters.add("String name2");
        arguments.add("'name2': name2");
        break;

      case "name3":
        parameters.add("String name3");
        arguments.add("'name3': name3");
        break;

      case "lexeme":
        parameters.add("Token token");
        conversions.add("String lexeme = token.lexeme;");
        arguments.add("'token': token");
        break;

      case "lexeme2":
        parameters.add("Token token2");
        conversions.add("String lexeme2 = token2.lexeme;");
        arguments.add("'token2': token2");
        break;

      case "string":
        parameters.add("String string");
        arguments.add("'string': string");
        break;

      case "string2":
        parameters.add("String string2");
        arguments.add("'string2': string2");
        break;

      case "string3":
        parameters.add("String string3");
        arguments.add("'string3': string3");
        break;

      case "type":
        parameters.add("DartType _type");
        ensureNameSystem();
        conversions.add(r"""
buffer = new StringBuffer();
new Printer(buffer, syntheticNames: nameSystem).writeNode(_type);
String type = '$buffer';
""");
        arguments.add("'type': _type");
        break;

      case "type2":
        parameters.add("DartType _type2");
        ensureNameSystem();
        conversions.add(r"""
buffer = new StringBuffer();
new Printer(buffer, syntheticNames: nameSystem).writeNode(_type2);
String type2 = '$buffer';
""");
        arguments.add("'type2': _type2");
        break;

      case "uri":
        parameters.add("Uri uri_");
        conversions.add("String uri = relativizeUri(uri_);");
        arguments.add("'uri': uri_");
        break;

      case "uri2":
        parameters.add("Uri uri2_");
        conversions.add("String uri2 = relativizeUri(uri2_);");
        arguments.add("'uri2': uri2_");
        break;

      case "uri3":
        parameters.add("Uri uri3_");
        conversions.add("String uri3 = relativizeUri(uri3_);");
        arguments.add("'uri3': uri3_");
        break;

      case "count":
        parameters.add("int count");
        arguments.add("'count': count");
        break;

      case "count2":
        parameters.add("int count2");
        arguments.add("'count2': count2");
        break;

      case "constant":
        parameters.add("Constant _constant");
        ensureNameSystem();
        conversions.add(r"""
buffer = new StringBuffer();
new Printer(buffer, syntheticNames: nameSystem).writeNode(_constant);
String constant = '$buffer';
""");

        arguments.add("'constant': _constant");

        break;

      case "num1":
        parameters.add("num _num1");
        conversions.add("String num1 = ${format('_num1')};");
        arguments.add("'num1': _num1");
        break;

      case "num2":
        parameters.add("num _num2");
        conversions.add("String num2 = ${format('_num2')};");
        arguments.add("'num2': _num2");
        break;

      case "num3":
        parameters.add("num _num3");
        conversions.add("String num3 = ${format('_num3')};");
        arguments.add("'num3': _num3");
        break;

      default:
        throw "Unhandled placeholder in template: '$name'";
    }
  }

  String interpolate(String name, String text) {
    text = text
        .replaceAll(r"$", r"\$")
        .replaceAllMapped(placeholderPattern, (Match m) => "\${${m[1]}}");
    return "$name: \"\"\"$text\"\"\"";
  }

  List<String> codeArguments = <String>[];
  if (index != null) {
    codeArguments.add('index: $index');
  } else if (analyzerCode != null) {
    // If "index:" is defined, then "analyzerCode:" should not be generated
    // in the front end. Instead, this field should contain the fully formed
    // name of the corresponding public Analyzer error const
    // (e.g. ParserErrorCode.EQUALITY_CANNOT_BE_EQUALITY_OPERAND)
    // which will be used when generating code in Analyzer
    // for translating fasta error codes to Analyzer error codes.
    codeArguments.add('analyzerCode: "$analyzerCode"');
  }
  if (severity != null) {
    String severityEnumName = severityEnumNames[severity];
    if (severityEnumName == null) {
      throw "Unknown severity '$severity'";
    }
    codeArguments.add('severity: Severity.$severityEnumName');
  }

  if (parameters.isEmpty && conversions.isEmpty && arguments.isEmpty) {
    if (template != null) {
      codeArguments.add('message: r"""$template"""');
    }
    if (tip != null) {
      codeArguments.add('tip: r"""$tip"""');
    }

    return """
// DO NOT EDIT. THIS FILE IS GENERATED. SEE TOP OF FILE.
const Code<Null> code$name = message$name;

// DO NOT EDIT. THIS FILE IS GENERATED. SEE TOP OF FILE.
const MessageCode message$name =
    const MessageCode(\"$name\", ${codeArguments.join(', ')});
""";
  }

  List<String> templateArguments = <String>[];
  if (template != null) {
    templateArguments.add('messageTemplate: r"""$template"""');
  }
  if (tip != null) {
    templateArguments.add('tipTemplate: r"""$tip"""');
  }

  templateArguments.add("withArguments: _withArguments$name");

  List<String> messageArguments = <String>[];
  messageArguments.add(interpolate("message", template));
  if (tip != null) {
    messageArguments.add(interpolate("tip", tip));
  }
  messageArguments.add("arguments: { ${arguments.join(', ')} }");

  return """
// DO NOT EDIT. THIS FILE IS GENERATED. SEE TOP OF FILE.
const Template<Message Function(${parameters.join(', ')})> template$name =
    const Template<Message Function(${parameters.join(', ')})>(
        ${templateArguments.join(', ')});

// DO NOT EDIT. THIS FILE IS GENERATED. SEE TOP OF FILE.
const Code<Message Function(${parameters.join(', ')})> code$name =
    const Code<Message Function(${parameters.join(', ')})>(
        \"$name\", template$name, ${codeArguments.join(', ')});

// DO NOT EDIT. THIS FILE IS GENERATED. SEE TOP OF FILE.
Message _withArguments$name(${parameters.join(', ')}) {
  ${conversions.join('\n  ')}
  return new Message(
     code$name,
     ${messageArguments.join(', ')});
}
""";
}
