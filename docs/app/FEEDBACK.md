# Feedback

Anyone using the app can report a problem or suggest a feature. Both become issues on the app's public GitHub repo,
`derekurban/fitness`, where they are triaged with everything else. The report is written in the app; on GitHub the
person only signs in and sends.

## How it works

Settings has a **Feedback** section with three rows:

- **Report a problem** opens a sheet shaped like the `bug.yml` issue form (labelled `bug`). It asks for a title ("In a
  few words") and **What happened**, both required. **What you expected** and **How to make it happen again** are
  optional, and **How often** is a choice of every time, sometimes or once so far.
- **Suggest a feature** opens a sheet shaped like `feature.yml` (labelled `enhancement`): a title and **The idea**,
  both required, and **Why it would help**, optional.
- **See what is reported** opens the repo's open issues, newest first.

The sheet shows what the app adds (the version, and for problems the phone) and says that sending needs a free GitHub
account and that reports are public. Once the required fields are filled in, **Continue on GitHub** opens the issue
form in the browser with everything filled in: title, every field, version and phone. If the person is signed out,
GitHub's sign-in keeps the whole link and lands back on the filled form. A screenshot can be attached there before
sending.

Drafts outlive the sheet while the app runs, so closing it or a failed sign-in loses nothing. After **Continue on
GitHub** the draft stays, and reopening the sheet says it was already taken to GitHub, with **Clear** to start another.

GitHub refuses links over its length limit, so each field is capped (1,500 characters for most). If a report still
makes the link longer than 6,000 characters, which takes text that encodes long, such as many accented letters, the
longest field is shortened with "…". The full report is then copied as Markdown, laid out like the issue, so it can be
pasted on GitHub. If nothing on the phone can open a web page, the link is copied instead.

## What is added, and what never is

- **Version**: the version name, the build number and, on staging, the flavour. For example
  `0.13.7 (build 100042) · staging`.
- **Phone** (problems only): maker, model and Android version. For example
  `Google Pixel 9 Pro · Android 16 (API 36)`.

Nothing else is attached: no history, levels, locations, calendar or goal, because issues are public. Everything can
still be edited on GitHub before sending.

## Why the forms only use text fields

A GitHub link can fill an issue form's text fields (inputs and textareas) by id, but not dropdowns or checkboxes. So
every field the app fills is a text field, and **How often** is an input the app fills from its choice.
`mobile/test/feedback_test.dart` fails if a filled field is missing from its form or is not a text field, or if the
app's label differs from the form's.

## Why not send from inside the app

Posting an issue needs a GitHub credential, and anything inside a public APK can be pulled out by anyone. Sending
reports without an account would need a small relay server that holds the credential and posts for the app. That was
set aside on 2026-10-18 because it opens a public endpoint and leaves reports with no one to reply to.

## Where it lives

| Path | What |
|---|---|
| `.github/ISSUE_TEMPLATE/bug.yml`, `feature.yml` | The issue forms. GitHub reads them from the default branch (`main`) |
| `mobile/lib/logic/feedback.dart` | The fields, the draft, the added lines, the link and its length budget, the copied text (pure, tested in `mobile/test/feedback_test.dart`) |
| `mobile/lib/ui/feedback.dart` | The Settings panel and the sheet |
| `mobile/lib/integrations.dart` | `LinkBridge` (channel `fitness/links`) opens the browser; `UpdateBridge.appInfo` also reports the phone |
