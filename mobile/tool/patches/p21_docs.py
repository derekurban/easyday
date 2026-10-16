import io
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:70])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

D = r'D:\Working\fitness\docs\app'
W = D + r'\WORKOUT.md'
patch(W, [
("""| Heavy and few | 4 to 6 | about 85 % | 3 minutes |
| Middle | 8 to 12 | about 70 % | 90 seconds |
| Light and many | 12 to 15 | about 60 % | 60 seconds |""",
 """| Heavy and few | 4 to 7 | about 85 % | 3 minutes |
| Middle | 8 to 12 | about 70 % | 90 seconds |
| Light and many | 13 to 18 | about 60 % | 60 seconds |"""),
("""The goal says which reps it likes, in one of those three words. Hard exercises train in that expression;
medium ones one step lighter; easy ones two steps lighter, so a strength goal squats heavy and curls
light, and a fitness goal does everything light and many.""",
 """The goal's program says which reps it likes: Strength (heavy), Build (middle), Endurance (light), or Mixed,
which alternates heavy and middle by workout, A and C heavy, B and D middle. Hard exercises train in that
expression; medium ones one step lighter; easy ones two steps lighter, so a strength program squats heavy
and curls light. Any exercise can be set to its own reps on its card, for the lifter who wants seven on
the bench and many on the calves whatever the program says."""),
("""Max estimates get loose past twelve reps, so the light expression
stops at 15 for loaded lifts.""",
 """Max estimates get loose past twelve reps, so the light expression
stops at 18 for loaded lifts."""),
("""Every exercise has a working level: its level, its working set count (from the goal, three by default,
settable 2 to 5), and the rep range of its expression. Sets stay inside that band for good; progress is
the level rising, never the sets. "Hit" means a set reached the top of the range. "In range" means it
reached the floor but not the top. "Short" means it did not reach the floor.""",
 """Every exercise has a working level: its level, its working set count (from the goal, three by default,
settable 2 to 5), and the rep range of its expression. Sets stay inside that band for good; progress is
the level rising, never the sets.

The range is a verdict, not a target. The instruction is always the same: as many as you can with good
form. Then the number says what it says: under the floor, the weight is too much; floor to just under the
top, fine, this is what training looks like; the top or more, ready for more. For 4 to 7: 3 says lower,
4 to 6 says fine, 7 or more says upgrade. "Hit" is the top or more, "in range" the floor to under the top,
"short" under the floor."""),
("""| Light | one lighter | the user's (bodyweight: one version down) | working sets minus one, at least two | two reps shy of the top |
| Working | the goal's | the user's | the working sets | the top |
| Extra | the goal's | the user's, then the next level for the push set | the working sets, plus a level-up set | the top; the floor on the level-up set |

Light is "do something": the same level in a lighter expression, with reps in reserve and a set fewer.
Nobody is demoted for picking easy. Working is the proper work. Extra is the proper work and then a
**level-up set**: one set at the next level, the next weight step or the next version, aiming for the floor
of the range. Reach it and the level is yours today. Fall short and the working sets still count as a hit.
At the ceiling, where there is no next level, the level-up set is the same level for two past the top. It
is something to work toward on a day the user feels fired up, and it uses the progression's own ladder.""",
 """| Light | the goal's | the user's, at 85 % of the usual weight; bodyweight: one version down | working sets minus one, at least two | the range, nothing judged |
| Working | the goal's | the user's | the working sets | as many as you can; the top or more is the signal to go up |
| Next level | the goal's | the next level, every set | the working sets | as many as you can; the floor on every set makes it yours today |

Light is "do something": the same reps at a lighter weight, a set fewer, nothing judged. A plate step is
the wrong unit for easy, so loaded exercises take a share of the usual weight (85 %, fixed for now,
tunable later per `IDEAS.md`); a version is a big enough step on its own, so bodyweight goes one version
down. Nobody is demoted for picking easy. Working is the proper work. Next level is the whole exercise one
step up, the next weight step or the next version, and is how a hard day gives the user something to work
toward: prove the next notch and it becomes the new normal. The expression never changes with energy."""),
("""| Hard | a level-up set on the hardest two (a setting: one to five, or all), working on the rest |""",
 """| Hard | the next level on the hardest two (a setting: one to five, or all), working on the rest |"""),
("""No budgets, no points. The same list at every energy; only the dials move. When a hard day's extra set does
not fit the minutes, it takes the time from the sets of a spare-minute exercise, last added first, never
below one set and never dropped. When even that is not enough, hard places no extra and says so: "your
usual; no room to push." It never drops an exercise to make room.""",
 """No budgets, no points. The same list at every energy; only the dials move. A hard day takes the same sets
and the same minutes as a normal one, one step heavier, so it always fits."""),
("""| Easy | squat light, bench light, pull-ups light, plank working, curl working | 2 + 2 + 2 + 3 + 3 | middle, 8 to 12, at 70 % of the level | about 65 % of your usual |
| Normal | all working | 3 each | heavy, 4 to 6, at 85 % | your usual |
| Hard | squat and bench extra, the rest working | 4 + 4 + 3 + 3 + 3 | heavy, 4 to 6, at 85 %, then one set at the next level for 4 | your usual, plus a level-up try on squat and bench |""",
 """| Easy | squat light, bench light, pull-ups light, plank working, curl working | 2 + 2 + 2 + 3 + 3 | heavy, 4 to 7, at 85 % of the usual weight | about 65 % of your usual |
| Normal | all working | 3 each | heavy, 4 to 7, at your level | your usual |
| Hard | squat and bench at the next level, the rest working | 3 each | heavy, 4 to 7, one plate step up | the next level on squat and bench |"""),
("""| At the working level | every working set hit the top, and the level-up set reached the floor at the next level | step up now |
| At the working level | every working set hit the top; no level-up set, or it fell short | hit: hit streak plus one |
| At the working level | every set in range, none short | hold: hit streak resets, nothing else |
| At the working level | any set short of the floor | miss: miss streak plus one |""",
 """| At the next level (a hard day) | every working set reached the floor | step up now: it is yours |
| At the next level, bodyweight | a set fell short of the floor | neutral: it was an attempt |
| At the next level, loaded | a set fell short | read by worth, below |
| At the working level | every working set at the top or more | hit: hit streak plus one |
| At the working level | every set in range, none short | hold: hit streak resets, nothing else |
| At the working level | any set short of the floor | miss: miss streak plus one |"""),
("""Step up after the step-up number of hits in a row (default one). Step down after the step-down number of
misses in a row (default two). The level-up set is the one way to skip the count: reaching the floor of the
range at the next level, right after the working sets, shows the next level is already there.""",
 """**Read by worth.** A loaded set is worth what it would be at the usual weight, by the same percent-of-max
table that defines the expressions (max is weight times one plus reps over thirty). So on a hard day a set
that fell one rep short at the next level is converted: seven at 72.5 kg is worth about nine at 70, which is
in range, so the exercise holds at the current level rather than being marked short. Below the floor's
worth is a miss; the top's worth or more is a hit. At the usual weight the worth is just the reps.

Step up after the step-up number of hits in a row (default one). Step down after the step-down number of
misses in a row (default two). A hard day is the one way to skip the count: the floor on every set at the
next level shows it is already yours."""),
("| Reps you like | from the template: heavy and few, middle, or light and many | Settings → Goal |",
 "| Program | from the template: Strength, Build, Endurance, or Mixed | Settings → Goal |\n| Reps, per exercise | the program's | the exercise card |"),
("| Hard day level-up tries | 2 | Settings → Goal, 1 to 5 or all |", "| Hard day: next level on | 2 | Settings → Goal, 1 to 5 or all |"),
])

A = D + r'\APPLICATION.md'
patch(A, [
("""- **Hit the top.** The set reached the top of the rep range. One tap.
- **In range.** The set reached the floor but not the top. The number is logged, one more tap. Holds the
  level: not ready to go up, no reason to go down.
- **Short.** The set did not reach the floor. The number is logged. The only outcome that can lower a
  level, and only at the working level.""",
 """The instruction is always "as many as you can with good form"; the range is a verdict, not a target.

- **The top or more.** Ready for more. One tap.
- **In range.** The floor to just under the top. The number is logged, one more tap. This is what training
  looks like: the level holds, not ready to go up, no reason to go down.
- **Short.** Under the floor. The number is logged. The weight is too much: the only outcome that can
  lower a level, and only at the working level.
- **Read by worth.** A set lifted at a different weight than the usual, a hard day's next level, is
  converted to what it would be at the usual weight before it is read, by the percent-of-max table."""),
("""- **Step up now.** A hit, and the level-up set that a hard day adds after the working sets reached the
  floor of the range at the next level. That shows the next level is already there; the count is skipped.
  If the level-up set falls short, it is still a hit.""",
 """- **Step up now.** A hard day trains the exercise at the next level on every set. The floor on every
  working set there shows it is already yours; the count is skipped. A set that falls short at the next
  level is read by its worth at the usual weight, so one rep short usually holds rather than misses."""),
("""- **Intent.** What a workout asks of one exercise today: light (a lighter expression, a set fewer),
  working (the working level), or extra (the working level, then a level-up set at the next level). A
  prescription, never a judgement.""",
 """- **Intent.** What a workout asks of one exercise today: light (85 % of the usual weight or one version
  down, a set fewer), working (the working level), or next level (one step up, every set). A prescription,
  never a judgement."""),
("""   working, the ones furthest behind on coverage; normal is working everywhere; hard is a level-up set on
   the hardest, as many as the setting asks and the minutes allow.""",
 """   working, the ones furthest behind on coverage; normal is working everywhere; hard is the next level on
   the hardest, every set, as many exercises as the setting asks."""),
("""   and so the weight), the sets, and the reserve. A push that does not fit takes a set from a spare-minute
   exercise; hard never drops an exercise to fit one, and says when there is no room.""",
 """   and so the weight), the sets, and the reserve. The expression never changes with energy; a hard day is
   the same sets and minutes one step heavier, so it always fits."""),
("| The goal: what to cover in order, the reps it likes, movement days | from the template | any order; heavy and few, middle, light and many |\n| Hard day level-up tries | 2 | 1 to 5, or all |",
 "| The goal: what to cover in order, the program, movement days | from the template | any order; Strength, Build, Endurance, Mixed |\n| Reps per exercise | the program's | heavy, middle, light |\n| Hard day: next level on | 2 | 1 to 5, or all |"),
])
patch(D + r'\EXERCISES.md', [
("""- **Last time.** The last prescription and outcome, so Today can say "last time: three sets at 60 kg, all
  hit.\"""",
 """- **Reps override.** Heavy, middle or light for this exercise regardless of the program, if the user set it.
- **Last time.** The last prescription and outcome, so Today can say "last time: three sets at 60 kg, all
  hit.\""""),
("| Difficulty, per exercise | library default | the exercise card |", "| Difficulty, per exercise | library default | the exercise card |\n| Reps, per exercise | the program's | the exercise card |"),
])
patch(D + r'\IDEAS.md', [
("""- **The time fit choosing expressions.**""",
 """- **The easy share as a setting.** Easy days lift 85 % of the usual weight, fixed. Make it tunable, 75 to
  90 %, if real easy days land wrong for someone.
- **A level-up set.** Hard was briefly one extra set at the next level after the working sets, instead of
  the whole exercise at the next level. Kept here in case a gentler hard day is wanted for beginners.
- **The time fit choosing expressions.**"""),
])
M = r'C:\Users\derek\.claude\projects\D--Working-fitness\memory\fitness-app-intent.md'
t = io.open(M, encoding='utf-8').read()
t = t.replace("/ working / extra (= a LEVEL-UP SET at the next level after the working sets, aim the floor; reach it = step up now; default 2 tries on hard).",
              "/ working / next level (hard: the whole exercise one level up, every set; floor on every set = step up now; default 2 exercises). Light = 85% of the usual weight (easyShare, fixed) or one version down. Sets are read BY WORTH (Epley reps-equivalent at the usual weight). Bands heavy 4-7 / middle 8-12 / light 13-18; the range is a verdict: short / in range / top-or-more. Programs: Strength, Build, Endurance, Mixed (A/C heavy, B/D middle); per-exercise reps override on the card.")
t = t.replace("working sets at top + level-up set reaching the floor at the next level = step up now.", "the floor on every set at the next level = step up now.")
io.open(M, 'w', encoding='utf-8', newline='\n').write(t)
print('docs ok')
