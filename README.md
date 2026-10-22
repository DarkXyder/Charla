# Charla

Conversation-first Spanish for English speakers (neutral Latin American Spanish), iOS 17+.

- **Lessons:** 8 beginner units (CEFR A1), each with words and phrases, a grammar tip and a mixed lesson:
  learning cards, listen and choose, choose the Spanish, build the sentence, type it (with an accent bar),
  say it aloud (speech recognition), match pairs. Missed exercises come back at the end.
- **Conversations:** each unit ends with a role-play (party, café, market, directions…). On iPhones with
  Apple Intelligence (iOS 26) the partner is Apple's on-device model: free conversation, corrections, tips
  and three suggested replies, private and offline. Elsewhere the role-play is guided by a script.
- **Review:** every word joins a spaced-repetition deck (simplified SM-2): Again / Good / Easy.
- **Habits:** XP, daily goal, streak, weekly chart, daily reminder.
- **Audio:** Apple's Spanish (Mexico) voice; long-press any speaker button for slow speech.

No servers, no accounts; progress is stored on the device.

## Content

`Charla/Content/course.json` holds the whole course (units → items, grammar, conversation). Edit it to fix or
add content; `{name}` in conversation lines is replaced by the learner's name. Have a native speaker review it.

## Build

GitHub Actions builds `Charla.ipa` on every push to `main` and publishes it under **Releases → Latest build**.
Install it with SideStore. On a Mac: `brew install xcodegen && xcodegen generate`, open `Charla.xcodeproj`.

The newest Xcode on the runner is used; with the iOS 26 SDK the AI partner is compiled in
(`#if canImport(FoundationModels)`), otherwise the app builds without it.

The icon is drawn by `design/icon.py` (Outfit font, SIL Open Font License).
