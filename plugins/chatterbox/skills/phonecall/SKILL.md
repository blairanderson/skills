---
name: phonecall
description: "Use when: user asks to make an outbound phone call, schedule something by phone, reschedule or confirm an appointment, get a quote by phone, follow up on a call, or any AI-driven voice outreach. Triggers on 'call them', 'call my dentist', 'phone the restaurant', 'make a call', 'schedule by phone', 'get a quote over the phone', 'reschedule my appointment'. Uses VOCAL (Voice Outreach Call Automation Layer) via the chatterboxagent.com API."
allowed-tools: Bash, Read, WebFetch
---

# VOCAL - AI Phone Calls

Make outbound phone calls using VOCAL's AI voice agents. The AI will call the specified number, have a conversation based on your objective, and report back with the results.

## Configuration

Check if an API key is configured at `skills.entries.vocal.apiKey` in the user's moltbot config.

- **If API key is present**: Make real calls via the VOCAL API
- **If API key is missing**: Return a simulated demo result with signup instructions

## Gathering Information

When the user asks you to call someone, gather these details before making the call:

| Field | Required | Description |
|-------|----------|-------------|
| `phoneNumber` | Yes | Phone number to call (US numbers can omit +1) |
| `callObjective` | Yes | What the call should accomplish - be VERY specific! |
| `fromName` | Yes | Who you're calling on behalf of |
| `recipientName` | No | Name of person you're trying to reach |

**CRITICAL: Think ahead to what information will be needed during the call.** Before making the call, ask yourself: "What questions will the recipient ask?" and make sure you have answers.

### Context Checklist by Call Type

**Scheduling calls (demos, appointments, meetings):**
- Available dates/times (specific windows, not just "next week")
- Meeting format: Zoom, Google Meet, Teams, phone, in-person?
- Duration needed
- Who will attend from the caller's side
- Contact email for calendar invite
- Any prep materials to share?

**Appointment changes (reschedule, cancel, confirm):**
- Patient/customer name for verification
- Current appointment date/time
- New preferred dates/times (give 2-3 options)
- DOB or account number if they'll ask for verification
- Reason for change (if relevant)

**Service inquiries (quotes, availability, information):**
- Specific services needed
- Location/address for the work
- Timeline/urgency
- Budget range (if relevant)
- Specific questions to ask (list them out)

**Follow-up calls:**
- Context from previous conversation
- What was promised or discussed
- What you need from them now

### Good Objectives (Complete Context)
- "Schedule a 30-minute Zoom demo for our HR software. I'm available Tuesday 2-5pm or Wednesday 10am-2pm EST. Send the invite to john@acme.com. It'll be me and our HR director Sarah attending."
- "Reschedule my dental cleaning. I'm John Smith, DOB 03/15/1985. Current appointment is Friday Jan 17th at 9am. I need to move it to the following week - Tuesday, Wednesday, or Thursday morning works best."
- "Get a quote for hydroseeding my backyard. Address is 123 Oak Lane, Seattle WA. About 5,000 sq ft. Want to know: minimum job size, price per sq ft, how soon they could start, and if they guarantee germination."

### Poor Objectives (Missing Key Info)
- "Schedule a demo for next Tuesday" (What time? What platform? Who's attending? Where to send invite?)
- "Reschedule my dentist appointment" (What's your name? Current appointment? Preferred new times?)
- "Ask about their services" (Which services? What do you need to know specifically?)

**Always ask the user for missing context before making the call.** A well-prepared objective leads to successful calls.

## Demo Mode (No API Key)

If `skills.entries.vocal.apiKey` is NOT configured, return a simulated result:

```
**VOCAL Demo Mode**

Simulated call to {phoneNumber}:
- **Status:** COMPLETED
- **Duration:** 2m 18s
- **Outcome:** {generate a plausible successful outcome based on the objective}

---

**To make real calls:**

1. Register at https://www.chatterboxagent.com/register
2. Get your API key from the dashboard
3. Add to `~/.clawdbot/moltbot.json`:

{
  "skills": {
    "entries": {
      "vocal": {
        "apiKey": "YOUR_API_KEY"
      }
    }
  }
}

Then try your call again!
```

## Live Mode (API Key Configured)

### Step 1: Create the Call

Make a POST request to create the call:

```
POST https://www.chatterboxagent.com/api/v1/calls
Authorization: Bearer {apiKey}
Content-Type: application/json

{
  "phoneNumber": "{phoneNumber}",
  "callObjective": "{callObjective}",
  "fromName": "{fromName}",
  "recipientName": "{recipientName or omit if unknown}",
  "maxRetries": 0
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "call": {
    "id": "cmg0veckz000flj5phpi9205m",
    "status": "INITIATED",
    ...
  }
}
```

**Error Responses:**
- `422` - Objective validation failed. Show the `validation.suggestions` to help the user improve their objective, or ask if they want to proceed anyway with `skipObjectiveValidation: true`
- `401` - Invalid API key
- `400` - Missing required fields

### Step 2: Stream Call Progress

Open an SSE connection to watch the call in real-time:

```
GET https://www.chatterboxagent.com/api/v1/calls/{callId}/stream
Authorization: Bearer {apiKey}
Accept: text/event-stream
```

**Events you'll receive:**

1. `status` - Call status updates
   ```json
   {"status": "INITIATED", "message": "Call queued and waiting to connect..."}
   {"status": "IN_PROGRESS", "message": "Call connected - conversation in progress"}
   ```

2. `transcript` - Live transcript updates during the call
   ```json
   {"transcript": "User: Hello?\nAssistant: Hi, this is..."}
   ```

3. `complete` - Final result when call ends
   ```json
   {
     "status": "COMPLETED",
     "outcome": "SUCCESS",
     "summary": "Successfully scheduled demo for Tuesday 2pm",
     "duration": 147,
     "transcript": "...",
     "extractedData": {...},
     "completedTasks": ["Scheduled demo", "Confirmed attendees"]
   }
   ```

4. `error` - If something goes wrong
   ```json
   {"message": "Internal server error"}
   ```

### Step 3: Report Results

Present the call results to the user:

```
**Call Completed** ({duration formatted as Xm Ys})

**Outcome:** {outcome}

**Summary:** {summary}

**Completed Tasks:**
- {each item from completedTasks}

<details>
<summary>Full Transcript</summary>

{transcript}

</details>
```

## Example Interactions

### Example 1: Gathering Missing Information

**User:** "Call my dentist to reschedule my appointment to next week"

**You:** "I can help reschedule your dentist appointment. I need a few details first:

1. What's the dentist's phone number?
2. What's your name (as it appears on their records)?
3. When is your current appointment?
4. What days/times work for you next week?
5. Will they need your date of birth to verify your identity?"

**User:** "555-234-5678, I'm John Smith, current appt is Friday at 9am, any morning next week works, and yeah my DOB is March 15, 1985"

**You:** "Got it. Calling now to reschedule John Smith's Friday 9am appointment to a morning next week..."

*[Make API call, stream results]*

**You:**
```
**Call Completed** (1m 42s)

**Outcome:** SUCCESS

**Summary:** Successfully rescheduled John Smith's cleaning from Friday 9am to Tuesday at 10am. Verified identity with DOB.

**Completed Tasks:**
- Verified identity as John Smith (DOB 03/15/1985)
- Cancelled Friday 9am appointment
- Rescheduled to Tuesday 10am
- Receptionist confirmed no conflicts
```

### Example 2: Complete Information Provided

**User:** "Call Grass Master at 555-345-6789 to get a quote for hydroseeding. I'm Sarah from BlueSky Landscaping. I need to know their minimum job size, price range, and if they travel to Bellevue. The job is about 8,000 sq ft."

**You:** "Great, you've given me everything I need. Calling Grass Master now..."

*[Make API call, stream results]*

**You:**
```
**Call Completed** (2m 15s)

**Outcome:** SUCCESS

**Summary:** Grass Master quoted $0.08-0.12/sq ft for hydroseeding. Minimum job is $650. They do travel to Bellevue (within their 2-hour radius). For 8,000 sq ft, estimate is $640-960.

**Completed Tasks:**
- Confirmed they offer hydroseeding
- Got minimum job size: $650
- Got price range: $0.08-0.12 per sq ft
- Confirmed they service Bellevue area
- Got estimate for 8,000 sq ft job
```

## Statuses Reference

| Status | Meaning |
|--------|---------|
| `INITIATED` | Call queued, waiting to connect |
| `IN_PROGRESS` | Call connected, conversation happening |
| `COMPLETED` | Call finished successfully |
| `FAILED` | Call failed (couldn't connect, error, etc.) |
| `CANCELLED` | Call was cancelled before completion |

## Outcomes Reference

| Outcome | Meaning |
|---------|---------|
| `SUCCESS` | Objective fully achieved |
| `PARTIAL_SUCCESS` | Some goals achieved, others not |
| `VOICEMAIL` | Reached voicemail |
| `NO_ANSWER` | No one answered |
| `BUSY` | Line was busy |
| `WRONG_NUMBER` | Reached wrong person/business |
| `DISCONNECTED` | Call was disconnected unexpectedly |
