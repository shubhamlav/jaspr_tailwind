import 'package:jaspr_tailwind/src/stylesheet.dart';
import 'package:test/test.dart';

void main() {
  group('usesV3Directives', () {
    test('v3 base', () {
      expect(usesV3Directives('@tailwind base;'), isTrue);
    });

    test('v3 components', () {
      expect(usesV3Directives('@tailwind   components;'), isTrue);
    });

    test('v4 utilities is not v3', () {
      expect(usesV3Directives('@tailwind utilities;'), isFalse);
    });

    test('v4 import is not v3', () {
      expect(usesV3Directives('@import "tailwindcss";'), isFalse);
    });
  });

  group('hasConfigDirective', () {
    test('hasConfigDirective', () {
      expect(hasConfigDirective('@config "../tailwind.config.js";'), isTrue);
    });

    test('no directive', () {
      expect(hasConfigDirective('@import "tailwindcss";'), isFalse);
    });
  });

  group('hasCssRules', () {
    test('banner only', () {
      expect(hasCssRules('/*! tailwindcss v4.3.3 | MIT License */\n'), isFalse);
    });

    test('empty', () {
      expect(hasCssRules('  \n'), isFalse);
    });

    test('real rule', () {
      expect(hasCssRules('/*! b */ .p-4{padding:1rem}'), isTrue);
    });
  });
}
