from pathlib import Path
p=Path('lib/src/widgets/completion_review_panel.dart');s=p.read_text(encoding='utf-8')
lines=[]
for line in s.splitlines():
 try:
  if 'â' in line or 'Â' in line: line=line.encode('cp1252').decode('utf-8')
 except (UnicodeError,ValueError): pass
 lines.append(line)
s='\n'.join(lines)+'\n'
s=s.replace("Text(\n                      'RoadAssist',", "Flexible(child: Text(\n                      'RoadAssist',")
s=s.replace("fontWeight: FontWeight.w800,\n                      ),\n                    ),\n                    const Spacer(),", "fontWeight: FontWeight.w800,\n                      ),\n                    )),\n                    const Spacer(),",1)
s=s.replace(" : 'Pay your provider directly',", " : 'Pay your provider directly',")
s=s.replace("                                            : 'Pay your provider directly',\n                                      ),", "                                            : 'Pay your provider directly',\n                                        style: const TextStyle(fontSize: 12),\n                                      ),")
p.write_text(s,encoding='utf-8')
