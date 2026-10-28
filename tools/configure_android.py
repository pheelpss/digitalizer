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
gradle.write_text(source, encoding='utf-8')
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
print('Digitalizer configurado: Android 7+, modelo OCR incorporado e rede removida do manifesto.')
