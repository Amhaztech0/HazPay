import re
from pathlib import Path

root = Path('lib')
color_import = "import 'package:zinchat/utils/color_extensions.dart';"
files_changed = []

for path in root.rglob('*.dart'):
    text = path.read_text(encoding='utf-8')
    if '.withOpacity(' not in text:
        continue
    
    replaced = text.replace('.withOpacity(', '.withPreciseOpacity(')
    if replaced == text:
        continue
    
    need_import = False
    if '.withPreciseOpacity(' in replaced:
        has_color_import = re.search(r"import\s+['\"]([^'\"]*)color_extensions\.dart['\"]", replaced)
        has_constants_import = re.search(r"import\s+['\"]([^'\"]*)constants\.dart['\"]", replaced)
        if not has_color_import and not has_constants_import:
            need_import = True
    
    if need_import:
        lines = replaced.splitlines()
        original_trailing_newline = replaced.endswith('\n')
        insert_idx = 0
        for idx, line in enumerate(lines):
            stripped = line.strip()
            if stripped.startswith('import '):
                insert_idx = idx + 1
        lines.insert(insert_idx, color_import)
        replaced = '\n'.join(lines)
        if original_trailing_newline and not replaced.endswith('\n'):
            replaced += '\n'
    
    path.write_text(replaced, encoding='utf-8')
    files_changed.append(str(path))

print(f'Updated {len(files_changed)} files')
