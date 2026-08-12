# instagram

Instagram automation skills. Everything runs through the user's logged-in
Chrome session (claude-in-chrome) — no cookie export, no credential handling.

## Skills

- **dm-video** — Download every video from an Instagram DM thread at full
  quality. Plays each video in Chrome, captures the signed DASH stream URLs
  from the network log, downloads the 1080p video + audio streams with curl,
  and merges them with ffmpeg.

## Requirements

- Chrome with the Claude extension, logged in to Instagram
- `ffmpeg` on PATH (`brew install ffmpeg`)
