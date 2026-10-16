import io
def patch(path, pairs):
    t = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in t, (path, old[:70])
        t = t.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(t)

D = r'D:\Working\fitness\docs\app'
patch(D + r'\WORKOUT.md', [
("""- **Energy is three dials, never a pick.** Each exercise gets an intent for today: light, working or
  extra. Intent sets the expression, the sets and the reserve. The same exercises appear at every energy,
  so for the same minutes hard is never emptier than normal, and normal never emptier than easy.""",
 """- **Energy is three dials, never a pick.** The list is built once, at normal, and fitted to the minutes.
  Energy then turns the dials on exactly that list: each exercise gets an intent for today, light,
  working or extra, and intent sets the expression, the sets and the reserve. Easy, normal and hard show
  the same exercises, added ones included; only the numbers beside them change.
- **Everything the user sees is relative to their usual.** The usual is the working level: their weight,
  their sets. A row shows today against that, "60 %", "usual" or "+1 set", with a three-bar meter, and
  the workout shows the same for the whole: "about 60 % of your usual", "your usual", "your usual, plus
  one extra set". An exercise's difficulty class (easy, medium, hard) is a property of the exercise, shown
  on its card and in the catalog, never as a measure of today."""),
("""No budgets, no points. The same list at every energy; only the dials move. When minutes are short the trim
order is light sets, then extra sets back to working, then the last exercise on the list, so a hard day in
a tight window degrades to a normal day before it loses an exercise.""",
 """No budgets, no points. The same list at every energy; only the dials move. When a hard day's extra set does
not fit the minutes, it takes the time from the sets of a spare-minute exercise, last added first, never
below one set and never dropped. When even that is not enough, hard places no extra and says so: "your
usual; no room to push." It never drops an exercise to make room."""),
("""4. **Fit the minutes.** Over: light sets first, then extra sets back to working, then the last exercise on
   the list, then the one that is left shrinks. Patterns dropped here come back first if room appears.
5. **Spend the spare minutes** as the goal says: more exercises, cardio, or rest.""",
 """4. **Fit the minutes at normal.** Working sets everywhere. Over: the last exercise on the list goes, then
   the one that is left shrinks. Patterns dropped here come back first if room appears.
5. **Spend the spare minutes** as the goal says: more exercises, cardio, or rest. Then turn the dials for
   the energy picked, on that list; a hard day's push may take a set from a spare-minute exercise."""),
("""| Energy | The same four exercises | Sets | Expression on the squat |
|---|---|---|---|
| Easy | squat light, bench light, pull-ups light, plank working, curl working | 2 + 2 + 2 + 3 + 3 | middle, 8 to 12, at 70 % of the level |
| Normal | all working | 3 each | heavy, 4 to 6, at 85 % |
| Hard | squat extra, the rest working | 4 + 3 + 3 + 3 + 3 | heavy, 4 to 6, at 85 % |""",
 """| Energy | The same five exercises | Sets | Expression on the squat | Shown as |
|---|---|---|---|---|
| Easy | squat light, bench light, pull-ups light, plank working, curl working | 2 + 2 + 2 + 3 + 3 | middle, 8 to 12, at 70 % of the level | about 65 % of your usual |
| Normal | all working | 3 each | heavy, 4 to 6, at 85 % | your usual |
| Hard | squat extra, the rest working | 4 + 3 + 3 + 3 + 3 | heavy, 4 to 6, at 85 % | your usual, plus 1 extra set |"""),
("""- Let energy pick or swap an exercise. Energy only turns the dials.""",
 """- Let energy pick, swap, add or drop an exercise. Energy only turns the dials.
- Show an exercise's difficulty class as if it were how hard today is. Today is always shown against the
  user's usual."""),
])

patch(D + r'\APPLICATION.md', [
("""3. **Give each exercise an intent** from the energy recipe: easy is light everywhere with two of the easy
   and medium exercises at working, the ones furthest behind on coverage; normal is working everywhere;
   hard is extra on the hardest, working on the rest. How many pushes hard gives is a setting. Intent sets
   the expression (the reps, and so the weight), the sets, and the reserve.
4. **Fit the minutes.** Light sets go first, then extra sets back to working, then the last light exercise
   on the list, then the last working one. Hard in a tight window becomes normal before it loses an
   exercise.
5. **Spend the spare minutes** as the goal says: more exercises, cardio, or rest. Cardio and stretching
   close the workout with their shares. More minutes always mean at least as many sets.
6. **Order it** extra and working first, light last, hardest first within each.""",
 """3. **Fit the minutes at normal** and spend the spare minutes as the goal says: more exercises, cardio, or
   rest. This list is the workout at every energy.
4. **Turn the dials** for the energy picked: easy is light everywhere with two of the easier exercises at
   working, the ones furthest behind on coverage; normal is working everywhere; hard is one more set on
   the hardest, as many as the setting asks and the minutes allow. Intent sets the expression (the reps,
   and so the weight), the sets, and the reserve. A push that does not fit takes a set from a spare-minute
   exercise; hard never drops an exercise to fit one, and says when there is no room.
5. **Cardio and stretching close it** with their shares. More minutes always mean at least as many sets.
6. **Order it** extra and working first, light last, hardest first within each. Every row and the whole
   workout are shown against the user's usual: "60 %", "usual", "+1 set"."""),
("""- **Today.** One workout, one start button, the energy picker and the minutes slider with their defaults
  filled, the swap control, and the location.""",
 """- **Today.** One workout, one start button, the energy picker and the minutes slider with their defaults
  filled, the swap control, and the location. Every row and the whole workout against the user's usual,
  so easy, normal and hard read as lighter, usual and more at a glance; never an exercise's class."""),
])
print('ok')
