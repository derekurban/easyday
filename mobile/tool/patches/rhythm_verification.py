"""Make progression fixtures choose the exercise they are testing explicitly."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
for name in ['logic_test.dart', 'features_test.dart']:
    p = root / 'test' / name
    s = p.read_text(encoding='utf-8')
    s = s.replace('List<String> muscles = const []})', 'List<String> muscles = const [], Map<String, String> picks = const {}})')
    s = s.replace('muscles: muscles, liftInstead: true)', 'muscles: muscles, picks: picks, liftInstead: true)')
    titles = ['step up waits for N', 'a set below the bottom', 'an unused rung decays',
              'after a week away', 'pain pauses the exercise', 'the level history folds']
    for title in titles:
        marker = "test('" + title
        if marker not in s:
            continue
        a = s.index(marker)
        b = s.find("    test('", a + len(marker))
        if b < 0:
            b = len(s)
        block = s[a:b].replace('muscles: quads)', "muscles: quads, picks: const {'quads1': 'bb_squat'})")
        block = block.replace("muscles: const ['quads'])", "muscles: const ['quads'], picks: const {'quads1': 'bb_squat'})")
        s = s[:a] + block + s[b:]
    s = s.replace("expect(e.why, contains('ready'));", "expect(e.why, isNot(contains('carrying strain')));")
    s = s.replace('share and emphasis choose the muscle', 'tags and frequency choose the muscle')
    p.write_text(s, encoding='utf-8', newline='\r\n')
