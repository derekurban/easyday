# Location

A location is a place the user trains, with the equipment that is there. The phone's position is a way to
pick one without asking, and a way to see how far away each one is.

## What it is

Two things that share a name:

- **Saved locations.** Named places with an equipment list, the user's own, filled from a template if that
  helps (commercial gym, home with dumbbells and a bench, hotel gym, nothing) and ticked to match what is
  really there. Every user has at
  least one. Each can carry a saved geographic position, or be marked **anywhere**: no fixed place, so it is
  never auto-picked by distance and is the fallback when nothing is near. A location with no equipment is
  anywhere by default.
- **The position integration.** Off by default. Turning it on allows the app to read the phone's position:
  once when the app opens, when the user asks for a refresh, and when a workout is being planned. With it on,
  the user can save a position on any location and the app auto-picks the nearest saved place when within
  about four hundred metres of it.

## What it reads

- A single position fix, medium accuracy, with an eight-second limit. Nothing in the background.
- The saved coordinates of each location, set by the user tapping "Save my position" while standing there,
  or updated the same way later.

## What it changes

- **Which exercises fill the workout.** Equipment decides which exercises can take each slot, and how far a
  bodyweight progression can go (loading gear such as a vest or dip belt opens levels above the top version).
  Levels belong to the exercise, not the place, so switching location never resets anything.
- **The location default.** With the integration on and a saved place nearby, Today and the planning flow
  open with that place selected and marked "nearby". Otherwise the default is the most used location. One tap
  picks another.
- **Nothing about levels, energy, or time.**

## Refresh and distance

A refresh control, on Today and in Settings → Locations, reads the position now and shows the distance to
every saved location that has one ("Commercial gym · 1.2 km", "Home · 14 km"). Anywhere locations show no
distance. This is for understanding where things are relative to you; it does not start anything.

## Planning a workout

Planning (see `CALENDAR.md`) chooses a location before it builds the preview, starting with the most used
location, or the nearby one if there is one. The plan is built for that place's equipment and can be changed
to another location ahead of time, which rebuilds the preview. The location is named in the calendar event.

## Where it shows

- Today: the location chip in the top corner, with a crosshair icon when it was picked by position, and the
  refresh control in the location sheet with distances.
- Settings → Locations: each location, its equipment count, "position saved" or "anywhere", the refresh
  with distances, and the position switch. Inside a location: save or update its position, or make it
  anywhere.

## Planned, not built

From section 12 of the application.

- **Arriving at a known gym:** one notification that today's workout is ready.
- **Leaving a gym with nothing logged:** one question, quick log?
- **At home on a likely training day:** offer the home version.
- **Away from every known location for two or more days:** switch to an anywhere location until back.

All four need position in the background or geofences, which cost battery and trust. They wait until the
foreground version has proved useful.

## What it never does

- Track movement, keep a history of positions, or read position while the app is closed.
- Send position anywhere. It is compared with saved coordinates on the phone and dropped.
- Create a location on its own. Only the user adds places.
- Change the workout because of where the user is, beyond choosing the equipment list.

## How it fits the rest

Location is the equipment side of the workout builder. The rotation is written in slot types; the location
says which exercises can fill them here. A user with two saved places and the integration on never thinks
about it: the right equipment list is there when the app opens. A user with one place never needs the
integration at all. See `APPLICATION.md` section 11 for how substitution between places keeps levels, and
`CALENDAR.md` for planning and the other default that sets itself.

## Settings

| Setting | Default | Where |
|---|---|---|
| Position on or off | off | Settings → Locations |
| Saved position or anywhere, per location | anywhere for no-equipment locations, otherwise none | Settings → Locations → the location |
| Nearby radius | 400 m | fixed for now |

## Open questions

- Whether the most used location should be counted over all time or the last few weeks.
- The rest are in `IDEAS.md`.
