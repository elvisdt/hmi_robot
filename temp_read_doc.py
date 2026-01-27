import zipfile, re, sys
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8')
path=Path(r'docs/UNIVERSIDAD PERUANA DE CIENCIAS APLICADAS.docx')
with zipfile.ZipFile(path) as z:
    data = z.read('word/document.xml').decode('utf-8')
text = re.sub(r'<.*?>','',data)
print(text)
