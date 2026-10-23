# Normalise the given files to CRLF line endings (the repo's convention), so a rewrite is not a whole-file diff.
import sys
for p in sys.argv[1:]:
    b = open(p, 'rb').read()
    s = b.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')
    if s != b: open(p, 'wb').write(s); print('crlf', p)
