"""Ajusta somente o scaffold Android do Digitalizer no build."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
gradle = root / 'android/app/build.gradle.kts'
if not gradle.exists():
    raise SystemExit('Gere primeiro a pasta Android com flutter create.')
source = gradle.read_text(encoding='utf-8')
source, count = re.subn(r'minSdk\s*=\s*[^\n]+', 'minSdk = 24', source)
if count != 1:
    raise SystemExit('Não foi possível localizar minSdk no scaffold.')
source = re.sub(r'compileSdk\s*=\s*[^\n]+', 'compileSdk = 36', source)
# Até validar o leitor no aparelho, não otimizar/ofuscar a camada nativa.
# A inserção é repetível, inclusive quando o Android é gerado no Codemagic.
source = re.sub(r'^[ \t]*is(?:MinifyEnabled|ShrinkResources)[ \t]*=[ \t]*(?:true|false)[ \t]*(?:\r?\n|$)', '', source, flags=re.M)
source, count = re.subn(r'(\brelease\s*\{)',
    r'\1\n            isMinifyEnabled = false\n            isShrinkResources = false',
    source, count=1)
if count != 1:
    raise SystemExit('Não foi possível configurar o release de diagnóstico.')
if '"proguard-rules.pro"' not in source:
    source, count = re.subn(
        r'(\brelease\s*\{)',
        r'\1\n            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")',
        source, count=1,
    )
    if count != 1:
        raise SystemExit('Não foi possível configurar as regras R8 no release.')
gradle.write_text(source, encoding='utf-8')
# O plugin referencia esses alfabetos como compileOnly. O Digitalizer usa Latin.
# Cobertura limitada aos tipos ausentes: não suprimir outros erros do R8.
optional = [
    'com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions',
    'com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions',
    'com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions',
    'com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions',
]
rules = '# Optional non-Latin types referenced by google_mlkit_text_recognition.\n'
for name in optional:
    rules += f'-dontwarn {name}\n-dontwarn {name}$Builder\n'
(root / 'android/app/proguard-rules.pro').write_text(rules, encoding='utf-8')
manifest = root / 'android/app/src/main/AndroidManifest.xml'
android = 'http://schemas.android.com/apk/res/android'
tools = 'http://schemas.android.com/tools'
ET.register_namespace('android', android)
ET.register_namespace('tools', tools)
tree = ET.parse(manifest)
element = tree.getroot()
application = element.find('application')
application.set(f'{{{android}}}label', 'Digitalizer')
application.set(f'{{{android}}}allowBackup', 'false')
for name, remove in [('android.permission.CAMERA', False),
                     ('android.permission.INTERNET', True),
                     ('android.permission.ACCESS_NETWORK_STATE', True)]:
    for permission in list(element.findall('uses-permission')):
        if permission.get(f'{{{android}}}name') == name:
            element.remove(permission)
    attrs = {f'{{{android}}}name': name}
    if remove:
        attrs[f'{{{tools}}}node'] = 'remove'
    element.insert(0, ET.Element('uses-permission', attrs))
tree.write(manifest, encoding='utf-8', xml_declaration=True)
print('Digitalizer 0.1.1: OCR Latin offline, sem minificação/redução de recursos nativos, rede removida.')
