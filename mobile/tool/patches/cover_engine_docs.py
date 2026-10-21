"""SELECTION.md: the engine, requirements then a cover. CRLF kept."""
import pathlib, sys

p = pathlib.Path(__file__).resolve().parents[3] / 'docs' / 'app' / 'SELECTION.md'
b = p.read_bytes()
crlf = b'\r\n' in b
s = b.decode('utf-8').replace('\r\n', '\n')

def sub(old, new):
    global s
    if old not in s:
        sys.exit(f'not found: {old[:70]!r}')
    s = s.replace(old, new, 1)

sub("""## Which muscles

The goal says how many exercises a workout holds (`WORKOUT.md`). Selection fills that many, one muscle each,
by these rules in order. A later rule only breaks ties left by an earlier one.
""", """## The engine

Selection works in two stages. First it settles the **requirements**: the muscles today must work as a main
muscle. Then it finds the **cover**: exercises whose primary muscles, between them, include every requirement.
An exercise does not have to be for one muscle; a squat meets quads and glutes at once. The goal says how many
exercises a workout holds (`WORKOUT.md`), and that number bounds the cover, not the requirements.

1. **Forced muscles** are requirements first, in the user's order, strained or not.
2. **Available muscles** join one at a time by the rules below, re-ranked against the cover so far, for as long
   as the cover of every requirement still fits the exercise count. Each time a muscle joins, the cover is
   worked out again from the start, so a later muscle can turn an earlier pick into one exercise that works
   both.
3. **A muscle the cover already works** as a main muscle joins the requirements at no cost.
4. **Places still free** once no other muscle fits give the requirements a second exercise each, in the same
   order. Manual stops at step 1: the forced muscles, each covered once, and spare minutes go to sets.

The cover itself takes the requirements most important first. A requirement an exercise already chosen works
as a main muscle is met. Otherwise it gets the best exercise for it by the rules under "Which exercise", with
two more in the middle: the exercise that works the most requirements still waiting wins, then the one that
works the fewest already met, so no muscle is worked twice in a day when that can be helped. Forcing lats and
biceps gives one chin-up rather than a pulldown and a curl.

Draw again sets a seed: available muscles are drawn at random among the ready ones instead of by share, and
exercises at random in place of practised and library rank. The same seed always draws the same workout.

## Which muscles

The available muscles join the requirements by these rules in order. A later rule only breaks ties left by an
earlier one.
""")
sub("""One exercise per muscle: a muscle takes a second exercise only when every other ready muscle that is behind
already has one.""", """One exercise per muscle: a muscle takes a second exercise only when no other muscle fits.""")
sub("""1. **Ready.** Every primary muscle strain-free, counting today's plan so far. Then the lowest shade.
2. **Preferred.** Liked, then fine and unrated together, then not for me.""", """1. **Ready.** Every primary muscle strain-free, counting today's plan so far. Then, in a cover, not for me
   last, the most requirements still waiting, and the fewest already met. Then the lowest shade.
2. **Preferred.** Liked, then fine and unrated together, then not for me.""")
sub("""A workout
is named for every muscle its places went to, in order, as a day: "Chest day", "Lats and biceps day",
"Upper back, triceps and forearms day". Long names are known and left for later.""", """A workout
is named for every muscle its exercises work as a main muscle, in order, as a day: "Quads, glutes, upper back
and chest day" for a squat, a row and a bench. Long names are known and left for later. Each row on Today says
every main muscle its exercise works.""")
sub("""  only. Done rebuilds the workout.""", """  only, an exercise that works several of them counting for each. Done rebuilds the workout.""")

if crlf:
    s = s.replace('\n', '\r\n')
p.write_bytes(s.encode('utf-8'))
print('ok')
