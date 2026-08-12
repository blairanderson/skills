---
name: dm-video
description: |
  Use when: the user wants to download videos from an Instagram DM thread,
  pastes an instagram.com/direct/t/... URL and asks to save the videos,
  says "download instagram videos", "save the videos from this chat",
  "grab the DMs videos", or wants DM video files on disk in full quality.
allowed-tools: Bash, ToolSearch, mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__computer, mcp__claude-in-chrome__read_network_requests, mcp__claude-in-chrome__browser_batch, mcp__claude-in-chrome__read_page, mcp__claude-in-chrome__javascript_tool, mcp__claude-in-chrome__find
---

# Instagram DM Video Downloader

Download every video from an Instagram DM thread at full quality (1080p + audio),
using the user's logged-in Chrome session. No cookies are exported, no credentials
are touched — Chrome does the authenticated browsing, and the video CDN URLs it
reveals are signed public URLs that plain `curl` can fetch.

**Why the browser is required:** DMs need the user's Instagram login. Videos in the
thread are lazy — there are no `<video>` elements and no media URLs in the DOM until
a video is actually played. The only reliable source of media URLs is the network
log while a video plays.

**Why ffmpeg is required:** Instagram serves DM videos as DASH — the picture and the
sound are two separate `.mp4` streams. You must download both and merge them.

## How Instagram DM video streaming works (read this first)

When a DM video plays, Chrome fetches byte ranges from URLs shaped like:

```
https://scontent-XXX.cdninstagram.com/o1/v/t2/f2/m483/AQ....mp4?...&efg=<base64>&...&bytestart=0&byteend=893
```

Everything you need is in the `efg` query parameter — it is **base64-encoded JSON**:

```json
{
  "vencode_tag": "dash_h264-basic-gen2_1080p",   // or _720p / _540p / _360p
  "xpv_asset_id": 1573781337461049,               // unique per video
  "duration_s": 26,
  "bitrate": 4929514
}
```

Rules that follow from this:

1. **One video = many URLs.** Each video produces 4 video-quality variants
   (1080p/720p/540p/360p) plus one audio stream whose `vencode_tag` starts with
   `dash-audio`. All share the same `xpv_asset_id`.
2. **Pick the pair:** the `dash_h264-basic-gen2_1080p` URL (highest bitrate) and
   the `dash-audio` URL **with the same `xpv_asset_id`**.
3. **Never filter the network log by "1080p" or "dash-audio"** — those strings are
   inside the base64 and will match nothing. Filter by `o1/v/t2` (media requests
   only) or `efg=`.
4. **Strip `&bytestart=...&byteend=...`** from the URL to get the whole file in one
   GET. Keep every other parameter — the URL is signed (`oh`, `oe` params).
5. The signed URLs **expire** (the `oe` parameter). Download promptly after capture.
6. `curl` needs **no cookies** — the signature is the auth.
7. `xpv_asset_id` is your dedup key. If a click produces only an already-seen
   asset id, that message was already captured (or you clicked the same video).

## Step 1 — Open the thread

Load the Chrome tools in ONE ToolSearch call (core set + `read_network_requests` +
`browser_batch`). Then:

1. `tabs_context_mcp {createIfEmpty: true}` — get a tab.
2. `navigate` to the thread URL: `https://www.instagram.com/direct/t/<thread-id>/`.
3. Wait ~3s, screenshot. You should see the conversation. If you see a login wall,
   stop and ask the user to log in to Instagram in Chrome first.

## Step 2 — Arm the network log BEFORE playing anything

Network tracking only starts on the first `read_network_requests` call. Call it
once, right after the page loads (any pattern, e.g. `o1/v/t2`). An empty result is
expected and fine — the log is now recording.

## Step 3 — Survey the thread

Scroll to the very top of the thread (`computer scroll up` at the message area,
repeat until the contact header card appears). Note:

- The DOM is **virtualized** — only ~2 media thumbnails exist in the DOM at any
  time. Do NOT count videos with a DOM query; count them by scrolling through.
- Videos show a ▶ play triangle at the top-right of the thumbnail. The triangle
  may be cut off for a partially scrolled item — a click will still tell you
  (photos open an overlay but produce **zero** `o1/v/t2` requests).
- Note caption text messages near video groups (e.g. "Bellevue erosion yes") —
  use them to name files later.

## Step 4 — Capture loop (repeat per video, top of thread → bottom)

For each video, in this exact order:

1. **Flush the log:** `read_network_requests {urlPattern: "efg=", limit: 1,
   clear: true}`. This attributes the next batch of requests to the next video.
2. **Click the video thumbnail** (center of it). A fullscreen overlay player opens
   and playback starts automatically.
3. **Wait 3–4 s** for the DASH segments to start flowing.
4. **Read the log:** `read_network_requests {urlPattern: "o1/v/t2", limit: 6}`.
   The first ~5 distinct URLs are the variant manifest probes — among them you
   will find the 1080p video URL and the dash-audio URL. Decode the `efg` param
   mentally (or with `base64 -d`) to confirm `vencode_tag` and `xpv_asset_id`.
5. **Dedup check:** if the `xpv_asset_id` is one you already downloaded, close the
   overlay and move on — you clicked an already-captured video.
6. **Download + merge immediately** (URLs expire) via Bash:

   ```bash
   cd <output-dir>
   curl -s -o vN_video.mp4 '<1080p URL with &bytestart/&byteend removed>'
   curl -s -o vN_audio.mp4 '<dash-audio URL with &bytestart/&byteend removed>'
   ffmpeg -y -v error -i vN_video.mp4 -i vN_audio.mp4 \
     -c copy -map 0:v:0 -map 1:a:0 NN-description.mp4
   rm vN_video.mp4 vN_audio.mp4
   ```

   Quote the URLs in single quotes — they contain `&` and `%`.
7. **Close the overlay:** press `Escape` (do not click — the X moves).
8. **Scroll down ~5 ticks** to bring the next video into view. Screenshot to aim
   the next click.

Batch steps 1–4 in a single `browser_batch` call — it is one round trip:
`[flush-log, click, wait 4s, read-log]`.

## Step 5 — Verify and name

When the bottom of the thread is reached and the last click yields only seen
asset ids, you are done. Then:

```bash
for f in *.mp4; do
  ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$f"
done
```

- Every file must have a duration close to the `duration_s` from its `efg` JSON.
- Rename files into thread order with short descriptions:
  `01-construction-sidewalk.mp4`, `02-erosion-slope.mp4`, ...
  Use the caption messages from Step 3 for the descriptions.
- Report the table (file, length, size) and the output directory to the user.

## Gotchas

- **The overlay eats clicks.** While the player overlay is open, thumbnail
  coordinates hit the overlay instead. Always `Escape` before the next click.
- **A click may land on the wrong item** when a thumbnail is partially scrolled.
  The asset-id dedup in Step 4.5 makes this harmless.
- **`javascript_tool` querying `document.querySelectorAll('video')` returns `[]`**
  even while a video plays — Instagram tears the element down aggressively.
  Do not waste time on the DOM; the network log is the source of truth.
- **Do not filter the log with default limit 100 and no pattern** — the page is
  chatty and the output will drown you. Always pass `urlPattern` and a small
  `limit`.
- **Audio bitrate looks tiny (~50 kbps).** That is normal — it is AAC mono/stereo
  speech. Do not "fix" it by picking a bigger URL.
- If `ffmpeg` is missing: `brew install ffmpeg`. Ask before installing.

## Output convention

Default output directory: `~/Downloads/instagram-dm-videos/` unless the user names
one (e.g. a Jekyll project's `_videos/` folder). Never commit the videos to git
without being asked; check `.gitignore` covers `*.mp4` when writing into a repo.
