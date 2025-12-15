from pathlib import Path

root = Path('lib')
files_changed = []

for path in root.rglob('*.dart'):
    text = path.read_text(encoding='utf-8')
    if '.withPreciseOpacity(' not in text:
        continue
    replaced = text.replace('.withPreciseOpacity(', '.withOpacity(')
    if replaced == text:
        continue
    path.write_text(replaced, encoding='utf-8')
    files_changed.append(str(path))

print(f'Replaced withPreciseOpacity in {len(files_changed)} files')
