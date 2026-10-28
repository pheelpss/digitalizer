"""Confere os tipos opcionais exatos citados pelo R8 e a regra do release."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
gradle = (root / 'android/app/build.gradle.kts').read_text(encoding='utf-8')
rule_path = root / 'android/app/proguard-rules.pro'
assert rule_path.exists(), 'Faltam regras R8 para os alfabetos opcionais do plugin.'
rules = rule_path.read_text(encoding='utf-8')
types = {
    'com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions',
    'com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions',
    'com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions',
    'com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions',
}
expected = types | {name + '$Builder' for name in types}
actual = set(re.findall(r'^-dontwarn\s+(\S+)\s*$', rules, re.M))
assert actual == expected, 'As regras precisam cobrir somente os oito tipos opcionais.'
assert 'proguardFiles(' in gradle and '"proguard-rules.pro"' in gradle
release = gradle.split('release {', 1)[1].split('}', 1)[0]
assert '"proguard-rules.pro"' in release, 'As regras precisam ser aplicadas ao release.'
assert release.count('isMinifyEnabled = false') == 1
assert release.count('isShrinkResources = false') == 1
assert 'isMinifyEnabled = true' not in release
assert 'isShrinkResources = true' not in release
assert 'TextRecognitionScript.latin' in (root / 'lib/scanner.dart').read_text(encoding='utf-8')
assert not re.search(r'TextRecognitionScript\.(chinese|devanagiri|devanagari|japanese|korean)',
                     (root / 'lib/scanner.dart').read_text(encoding='utf-8'))
print('Release de diagnóstico: classes/recursos nativos preservados; OCR Latin mantido.')
