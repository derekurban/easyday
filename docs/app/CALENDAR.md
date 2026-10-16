# Calendar

The calendar tells the app the shape of the user's day, and gives the user a place to see their workouts
next to everything else. It is one section in Settings with its own switch, and everything below is off
until that switch is on and the permission is granted.

## What it is

An optional integration. When on, the app reads the day's events, writes its own events, and nothing else.
Three ideas carry the whole feature:

- **The awake window.** The hours the user counts as their day, 08:00 to 22:00 by default, editable. Every
  calculation happens inside it.
- **Three kinds of minute.** Inside the window every minute is free, busy, or workout. Busy comes from the
  user's events, merged where they overlap. Workout comes from events the app wrote. Free is the rest.
- **Defaults, never decisions.** The calendar can set the two daily defaults and suggest a time. One tap or
  one drag overrides it, and a default the app set never counts as the user's choice, so it never teaches the
  app anything. Levels are never touched.

## What it reads

- Timed events on the chosen calendars, today, from midnight to midnight, then clipped to the awake window.
- All-day events and declined events are ignored.
- Events the app wrote are recognised by id and counted as workout minutes, not busy.

## What it changes

**A busy day makes a lighter day.** The busy share of the awake window drives the defaults, with one line
under the pickers saying why. First cut, to be tuned on real days:

| Busy share of the awake window | Time default | Energy default |
|---|---|---|
| under 50 % | unchanged | unchanged |
| 50 % to 70 % | 25 minutes, if that is less than last time | unchanged |
| over 70 % | 25 minutes | easy |

Time moves first because busyness is literally time; energy only when the day is clearly heavy. The whole
adjustment has its own switch, and both thresholds are settings.

**A suggested slot.** Given the minutes the user has, the app finds the first free gap at least that long
inside the awake window, skipping the first hour after waking and the last hour before sleep. If only those
hours are free, it offers one of them with an advisory rather than refusing. Over time it prefers the hour
the user actually tends to start.

## Planning a workout

Planning is its own flow, reached from Today or from the calendar section. It exists so a workout can be
looked at, moved, or changed ahead of time, instead of only at the moment of starting.

1. **Pick the day and the slot.** Today by default; the suggested slot is offered first, any other time can
   be chosen, and the advisory shows for the first and last hour of the window.
2. **Pick the location.** The most used location first, or the nearby one when position is on (see
   `LOCATION.md`). The preview is built for that place's equipment. Changing the location rebuilds it.
3. **Set energy and minutes.** The usual two questions, with the calendar's defaults already filled.
4. **Preview.** The workout as it would be built: exercises, levels, sets, about how long. Swaps and level
   edits work here as they do on Today.
5. **Put it on the calendar.** With "plan a slot" on, the event is written (below). Without it, the plan is
   simply remembered and Today opens with it on the day.

A plan is a default like any other. When the day comes, Today shows the planned workout with its location,
energy and minutes filled in; anything can still be changed, and the workout that actually happens is what
gets judged and logged.

**The declinable event.** The planned slot is written to the calendar as an event the app owns: marked
tentative, set to free so it blocks nothing, titled as a question such as "Workout? A · 35 min at Commercial
gym". The description carries the suggested plan: the location, the exercises with their levels and sets,
and the estimated time. Deleting the event in the calendar is how the user declines; the app notices on next
open and does not write another that day. Android has no draft events and a user cannot invite themself, so
this is the closest honest shape: it shows up, it is clearly not a commitment, and it can be dismissed where
it appears. Editing the plan in the app rewrites the event; editing the event's time in the calendar moves
the plan. Both directions go through the sync below.

**Sync and "last synced".** The app and the calendar are two copies, and the calendar can lag: the phone's
provider syncs to Google or Exchange on its own schedule, and the app only reads when it is open. So the app
syncs on the lifecycle hooks (open, resume, after any write of its own) and when the user asks, never on a
timer in the background, and it shows "last synced 2 min ago" wherever calendar data is shown: on Today beside the suggested slot or planned workout, and in the
calendar section. A sync reads today's events and the app's own events back, applies any time change or
deletion made in the calendar to the plan, and rewrites any event the app changed. If the two copies ever
disagree, the user can see when the app last looked and can tap to look again, rather than wondering which
one is right.

**Auto-track.** Start and end times are recorded locally for every workout, calendar or not. With
auto-track on, finishing a workout writes "Workout A · 42 min at Commercial gym" from start to end on the
chosen calendar, with the description updated to what actually happened: the exercises, the levels used,
the sets and reps, and the one line about what changed. If a planned event exists for that day it is
converted into the log rather than duplicated. A plain stop still logs. Nothing is written for a workout
that never started.

## Where it shows

- Today: the busy-day line under the pickers, the suggested slot with its advisory when relevant, a planned
  workout for today when there is one, the way into planning, and "last synced" with a tap to sync now.
- Settings → Calendar: the switch, the calendar to write to, awake hours as a band, the busy-day adjustment
  and its thresholds, plan a slot, auto-track, and a plain readout of today: free, busy and workout minutes,
  with "last synced" and a sync-now control, so the user can
  check the app sees what they see.

## Time and zones

- Timestamps are stored as UTC. Day boundaries, the awake window and "done for today" use the phone's current
  local zone.
- Events are written with the zone they happened in, so a workout logged while travelling shows at the local
  time it was done.
- The daily reminder is rescheduled when the app resumes, in case the zone changed underneath it.
- Crossing the date line mid-day can make "done for today" right or wrong by a few hours. Accepted.

## What it never does

- Edit or delete an event it did not create.
- Keep a copy of the calendar or send it anywhere.
- Judge a missed day by what was on the calendar, or count workouts against it.
- Move a level, or send more than one nudge for any reason.

## How it fits the rest

The calendar is one of the ways the app answers the two daily questions before the user does. Energy
defaults come from recent workouts, from being away, and from a heavy day. Time defaults come from last time,
from running out of time, and from a busy day. The suggested slot is the calendar's version of the person
state's one nudge: a time, not a demand. The workout log on the calendar is section 8.7's "to the human"
living outside the app. See `LOCATION.md` for the other default that sets itself.

## Built so far

As of 0.12.0: the switch, the awake hours, the busy-day adjustment with both thresholds, the readout of
today with "last synced" and sync now, the suggested slot on Today with its advisory, auto-track with the
calendar to write to. The app reads on open and when asked, never on a timer. Planning a slot ahead of time,
the declinable event and the two-way sync wait on the planning flow (`IDEAS.md`).

## Settings

| Setting | Default | Range |
|---|---|---|
| Calendar on or off | off | |
| Calendar to write to | the phone's primary | any writable calendar |
| Awake hours | 08:00 to 22:00 | any window of 6 hours or more |
| Busy-day adjustment on or off | on | |
| Busy share that shortens the default | 50 % | 30 to 90 % |
| Busy share that also makes the default easy | 70 % | the first threshold to 100 % |
| Plan a slot on or off | off | not built yet |
| Planning location default | most used, or nearby | any saved location |
| Auto-track on or off | off | |
| Advisory hours after waking and before sleep | 1 hour each | fixed for now |

## Open questions

- Whether the suggested slot should be written every morning or only when the user plans one.
- How far ahead planning should reach: today and tomorrow, or the whole rotation.
- Whether a free gap should prefer the user's usual hour over the earliest gap once there is history.
- Whether to read tomorrow as well, so a quiet evening before a packed day can suggest training tonight.
