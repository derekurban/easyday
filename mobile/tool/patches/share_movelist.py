# Move HowToSteps out of stage_art.dart and _MoveList/_needs out of session.dart into widgets.dart (already written there).
import re, io
def rw(p, fn):
    b = open(p, 'rb').read(); s = b.decode('utf-8'); crlf = '\r\n' in s
    s2 = fn(s.replace('\r\n', '\n'))
    if crlf: s2 = s2.replace('\n', '\r\n')
    open(p, 'wb').write(s2.encode('utf-8'))

def stage(s):
    i = s.index('class HowToSteps extends StatelessWidget {')
    # drop the class (to the end of file)
    s = s[:i].rstrip('\n') + '\n'
    s = s.replace("import 'widgets.dart';\n", "import 'widgets.dart';\n\nexport 'widgets.dart' show HowToSteps;\n", 1)
    return s

def session(s):
    i = s.index('/// An accordion of things to do:')
    s = s[:i].rstrip('\n') + '\n'
    # _needs helper -> cardioNeeds
    j = s.index('  /// What a cardio option needs, in words')
    k = s.index('  bool _lowerDay', j)
    s = s[:j] + s[k:]
    s = s.replace('_needs(c)', 'cardioNeeds(c)')
    s = s.replace('_MoveList(', 'MoveList(')
    s = s.replace("_MoveList([for (final mv in moves) (name: mv.n, detail: '${mv.seconds} seconds', how: mv.how)]", "MoveList([for (final mv in moves) (name: mv.n, detail: '${mv.seconds} seconds', how: mv.how)]")
    return s

rw('lib/ui/stage_art.dart', stage)
rw('lib/ui/session.dart', session)
print('ok')
