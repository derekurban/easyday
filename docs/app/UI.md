# UI

How every screen of the app is laid out and worded. The rules were found on the workout screen (October 2026)
and apply everywhere else: a screen is for doing one thing, and everything on it either helps that thing or
goes.

## The rules

1. **Information is loud, instruction is quiet.** The thing the user is looking at gets the big type: the
   exercise, the day, the level. Anything that tells them what to do or how the engine works is small grey
   type, a picture, or absent. Explanations live in How it works, not on the screen that uses the word.
2. **One skeleton, fixed positions.** A screen is a title, one fact row with an icon, a picture or figure,
   then sections. Every state of the screen keeps those at the same place, so nothing jumps.
3. **One clock, and no clock hurries anyone.** Only the workout's own clock is shown. Nothing counts down,
   nothing fills toward a plan.
4. **Show the kind of thing, say the specifics.** A picture or figure carries the type and mood (the stage
   art, the body figure). Words carry the name, the target, the weight. Taglines are three words.
5. **Instructions are steps, not paragraphs.** A how-to is numbered steps. A list of moves is an accordion
   that opens one at a time.
6. **A button says what happens.** Start workout, Log 10 reps, Save as my level, Return. One filled button
   per view; everything else outlined or text.
7. **A mode changes the controls, not the screen.** Paused sinks the button and names it Paused. Nothing
   overlays, nothing banners.
8. **Geometry carries meaning.** The strip is a block per set and per timed part, all the same width: it
   reads as a count of steps. Done, skipped, now and ahead each have a colour.
9. **Looking is free.** Browsing never changes anything. A done value is edited with the same control that
   entered it, and saves as it turns.
10. **Accent is ink and marks, never a background.** Green goes on the strip, the number in the window, the
    weight, a step number, the one button. Never on a card.
11. **Polish tokens.** Gutter 16. Card radius 14. Full-width buttons 56. Section headers are sentence case
    with an icon (`SectionHeader`). Step numbers are `StepNumber`. Colours are checked in both themes.
12. **Logic lives in logic, with tests.** A screen draws a view model; it never computes one.
13. **Haptics on every state change.** A selection tick for browsing and picking, a light tap for starting
    and pausing, a medium one for logging.

## The screens

- **Today.** Title: the day's name. Fact row: exercises, sets, about how long; at the right, today against the
  usual. The body figure painted with today's muscles, in the picture slot; tap it for the muscle picker. The
  plan: a row per part, name and level on the left, minutes on the right, a chevron on every row. A tag only
  when today differs from the usual. Under the plan the strip as the workout will show it and one line: about
  how long and when it ends. A text link to walk or stretch instead. The dock: energy, time, and one button,
  Start workout. On a movement day: the same skeleton with the stage picture and the how-to or the moves.
- **The exercise sheet.** The exercise, its facts, a line on why it is here. Up, Down and Skip. The level as the
  progression, tap a level for today, a link to make it yours. Swap for: the alternatives in recommended order.
  Then the how-to at that level.
- **Done for today.** The check, the one line, the workout as a row of facts, one quiet line, and two ways on.
- **Progress.** Workouts per month, then days active and workouts all time as facts. Muscle strain: the figure
  and one line, a strip per muscle. Rhythm: a row per muscle, two facts each. Levels, last 30 days. Recent
  workouts.
- **Exercises.** Search, filters, the index. One line per exercise: the name, its level when practised, the
  difficulty word at the right.
- **Exercise card.** Title: the name. Fact row: the muscles it works and the difficulty. The stage picture.
  The level as facts: the weight or version, about how long a set, the best total, workouts. How to do it as
  steps. The progression as a track. Reps as a row of ranges. Difficulty with its override. Your word.
- **Settings.** Sections with sentence-case headers. One line per tile; details behind the tap. The goal as a
  row that opens the goal sheet. The six plain-word settings as chips or sliders, no explanation beside them.
- **Goal.** Name, a template to fill from, the rep ranges, three bands (exercises, sets, hard-day pushes),
  spare minutes, cardio and stretching shares, movement days, the muscles.
- **Location.** Name, a template to fill from, the position, the equipment by group.
- **Onboarding.** Five pages, one question each: how it works, the goal as a template, about you (experience
  and days a week), where you train as a template, units. Everything can be changed later in Settings.
