from pathlib import Path
p=Path('lib/src/widgets/completion_review_panel.dart');s=p.read_text(encoding='utf-8');a=s.index("                      Text(\n                        'RoadAssist',");b=s.index('                      const Spacer(),',a);s=s[:a]+'''                      Expanded(
                        child: Text('RoadAssist', maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      ),
'''+s[b+len('                      const Spacer(),\n'):];p.write_text(s,encoding='utf-8')
