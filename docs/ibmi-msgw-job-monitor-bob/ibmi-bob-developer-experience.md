# I Built a Real IBM i Application with Bob — Here's What Actually Happened

*An RPG developer's honest account of using AI-assisted development on IBM i*

---

I have been writing RPG on IBM i for years. I know the platform well enough to know that building even a "simple" screen takes time. You have to think through the DDS layout, wire up the subfile, handle indicators, write the SQL cursor, test the compile, fix the messages, test again. It is not difficult if you know what you are doing — but it takes time.

So when I heard about **IBM Bob** and its **Premium Package for IBM i (PPI)**, I was curious. Not hyped. Just curious. I wanted to see whether it could actually help with real IBM i work — not toy examples, but a proper green-screen application with DDS, embedded SQL, and operator actions.

This is an honest account of what happened.

---

## Why I Built This

The project came from something I had seen in a few IBM i shops. The operations team — the people who actually know the platform — are comfortable using `WRKACTJOB`. They know how to find a MSGW job and deal with it. But increasingly, production monitoring is being shared with **Level 1 service desk analysts** who do not have that background.

When a batch job enters **MSGW (Message Wait)** status, it has stopped and is waiting for an operator to reply to a system message. If nobody catches it, the job just sits there. Payroll waits. An overnight inventory run stalls. EDI does not go out. The impact is real.

The existing process asked L1 analysts to open `WRKACTJOB`, scroll through potentially hundreds of active jobs, spot the MSGW ones, and then figure out what to do next. That is not realistic for someone who was not trained on IBM i commands.

I wanted to build something focused: a screen that shows only the MSGW jobs, with labelled action options right there on the screen. No native commands. No scrolling through hundreds of rows. Open it, see the problems, take action.

A small application. A real use case. Good enough to actually test what Bob could do.

---

## Getting Started with IBM Bob Developer Mode

Before I describe what happened, I should explain the setup.

IBM Bob is an AI development assistant. I was using it in **Developer Mode**, which gives it access to IBM i tools — it can read source members, compile programs, run SQL, and check job logs. The IBM i capabilities come from the **Premium Package for IBM i (PPI)**, which connects Bob to the live system.

This is different from asking a general AI chatbot to write RPG code and then copying it into an editor. Bob is connected to the actual IBM i system. It can run queries against `QSYS2`, compile source members, and see the compiler output in real time. When something fails, it can read the job log. That changes the experience significantly.

---

## The First Prompt

I kept the first prompt short on purpose. I wanted to see what Bob would do with a minimal requirement before I started adding details.

Here is exactly what I typed:

> *"An operations team needs a real-time job monitoring screen on IBM i. Write a fully free RPGLE program and its DDS display file that lists all jobs currently in MSGW (message wait) status. Operators can take action on each job."*

No field list. No mention of SQL services. No mention of subfiles or DDS keywords. Just the problem.

[Screenshot — The original prompt typed into IBM Bob Developer Mode chat interface]

I expected Bob to ask me clarifying questions or produce something generic. It did neither.

---

## Bob's Implementation Plan

Before writing any code, Bob came back with a structured plan. This was the first thing that surprised me. It laid out:

- Which data source to use and why
- The screen architecture it would build
- What operator actions to support
- Which source files and members to create

On the data source, Bob said it would use `QSYS2.ACTIVE_JOB_INFO()` — an IBM i SQL table function that gives a real-time snapshot of active jobs — filtered with `WHERE JOB_STATUS = 'MSGW'`. I had used this service before, but I was curious how Bob would know to choose it over other options.

The answer makes sense when you think about it. `ACTIVE_JOB_INFO()` is a table function, which means you query it with standard SQL and get back rows. No CL commands, no `WRKACTJOB`, no screen-scraping. It is the right tool for this job and Bob chose it correctly.

For the screen, Bob planned a classic IBM i **subfile** pattern. One row per MSGW job, scrollable, with an option field. A separate FOOTER record for the function key legend. A message subfile on line 24 for operator feedback. Exactly how I would have designed it.

It also planned seven operator actions:

- `2` = Work With Job
- `3` = Hold Job
- `4` = End Job (Controlled)
- `5` = Display Messages
- `6` = Release Job
- `7` = Display Job Log
- `8` = End Job (Immediate)

I approved the plan without changes. That upfront step was valuable because it gave me a chance to check the direction before any code existed. If I had wanted to change the data source or add a different action, that was the right moment.

---

## The IBM i Skills Bob Used

I should explain something about how Bob works. IBM Bob has a set of **IBM i Skills** — specialised knowledge modules it activates based on what it is being asked to do.

For this project, Bob activated:

- **RPG Primer** → led to the ILE RPG free-format sub-skill for generating `**free` SQLRPGLE
- **DDS Primer** → led to the Display Files sub-skill covering subfile patterns, `OVERLAY`, and message subfiles

These skills are not just templates. They contain the kind of specific IBM i knowledge that is hard to find — things like the correct behavior of `OVERLAY` on a subfile control record, or why `QCMDEXC` needs `char` not `varchar` for its command parameter. I will come back to both of those.

---

## Code Generation

Bob generated two source members:

- `BOB4IPGMR/QDSPFSRC(MSGWDSPF)` — the DDS display file
- `BOB4IPGMR/QRPGLESRC(MSGWMON)` — the SQLRPGLE program

[Screenshot — IBM Bob Developer Mode showing the generated DDS source member MSGWDSPF in the source editor]

The DDS had five record formats. The subfile record `MSGSFL` held the job fields plus a hidden 28-character field `SFQJOB` to store the full qualified job name. The subfile control record `MSGCTL` had the screen title, column headings, and a job count field that would show green when MSGW jobs existed and yellow when the list was empty.

The hidden `SFQJOB` field was an interesting choice. Bob put the full qualified job name — format `number/user/name` — in a hidden field on each subfile row. When the operator types an option and presses Enter, the program reads the selected rows and uses that hidden field to build the CL command. No reconstruction, no guessing. The data travels with the row.

[Screenshot — DDS source showing the MSGSFL subfile record format with the hidden SFQJOB field highlighted]

The RPGLE program was fully free-format. The SQL cursor used `ACTIVE_JOB_INFO()` with a `WHERE JOB_STATUS = 'MSGW'` filter, and it used a nested `LOCATE` + `SUBSTR` expression to extract just the short job name for display while keeping the full qualified name in the hidden field.

[Screenshot — RPGLE source showing the SQL cursor declaration with the SUBSTR/LOCATE expression for extracting the short job name]

The `ProcessOptions` subroutine read changed subfile rows with `READC`, checked the option field, built a CL command string, and called `QCMDEXC`. For destructive operations like hold and end, the code used `monitor`/`on-error`/`endmon` blocks so a failed command would show an error message rather than crash the program.

---

## First Compilation

Bob compiled both members directly from the chat. The display file compiled clean first time. The RPGLE compile also completed — highest severity 00, zero errors, zero warnings.

[Screenshot — Bob Developer Mode showing the compile output for MSGWMON with "Highest severity: 00" highlighted]

I called the program to test it. The screen came up. The MSGW job that happened to be running on the test system appeared in the list correctly.

At this point I had a working application from a single prompt, in under ten minutes. But I was not done testing.

---

## My Enhancement Requests

After seeing the first working version, I made a couple of small changes.

The screen had the `F5=Refresh` label in two places — once in the subfile control header and once in the FOOTER record. I asked Bob to remove the duplicate. It changed exactly that one line and nothing else. No regeneration of the whole file. Just the one constant removed.

I also asked Bob to confirm the job count color logic. I wanted green when jobs exist (meaning attention is needed) and yellow when the list is empty (meaning everything is fine). Bob confirmed that indicator 35 already handled this correctly — `CntGrn = (WkJobCnt > 0)` — and showed me the DDS keywords that depended on it.

These were small requests. What I noticed was that Bob made targeted changes. It did not rewrite things that did not need rewriting.

---

## The Runtime Bug

This is where it got more interesting.

After the enhancements compiled, I pressed F5 to refresh the screen and noticed the function key legend on lines 22–23 had disappeared. Every time the subfile refreshed, the FOOTER record was wiped off the screen.

I reported it to Bob exactly as I would report a bug to a colleague:

> *"The function key footer disappears every time the subfile refreshes."*

Bob came back with a precise explanation. When you execute `EXFMT MSGCTL`, the 5250 data stream performs a full-screen write. Without the `OVERLAY` keyword on the subfile control record, that write clears everything on the screen that was not written in that operation — including the FOOTER record that had been written separately before the main loop started.

The fix was one keyword in the DDS:

[Screenshot — Side-by-side diff showing the MSGCTL record format before (missing OVERLAY) and after (OVERLAY added)]

One keyword. Bob found it, explained why it was needed — specifically the 5250 write semantics — and applied the fix. After recompiling, the footer stayed on screen correctly through every refresh.

I want to be honest here: I have known about `OVERLAY` for years. But in this case I had not thought carefully about the interaction between the separately-written FOOTER record and the subfile control `EXFMT`. Bob caught it. That was a good catch.

---

## The Bugs Bob Also Caught

The footer issue was the most visible problem, but there were a few others that came up during testing.

**The qualified job name was corrupt.**

The first version of the option processing was rebuilding the qualified job name by concatenating `JobNumber + '/' + JobUser + '/' + JobName`. What was not obvious is that `JOB_NAME` from `ACTIVE_JOB_INFO` is already the complete qualified name in `number/user/name` format. The code was double-encoding it, producing names like `327961/BOB4IPGMR/327961/BOB4`, which were truncated at 28 characters and wrong. Every CL command was failing with "job not found".

Bob spotted this immediately when I reported the command failures. The fix was to assign `SFQJOB` directly from `JOB_NAME` without any reconstruction, and use the SQL `SUBSTR` expression separately to extract the short name for display only.

[Screenshot — RPGLE source showing the corrected assignment: SFQJOB = %char(JobRow.JobName)]

**The QCMDEXC prototype was wrong.**

This one is worth explaining in detail because it is genuinely obscure.

The initial prototype declared the `Cmd` parameter as `varchar(32702) options(*varsize)`. In ILE RPG, when you pass a `varchar` variable to a `varchar OPTIONS(*VARSIZE)` parameter, the compiler includes the internal 2-byte length prefix as part of the data that gets passed to the called program. So `QCMDEXC` receives the two bytes of the length field as the first two characters of the command string. It reads `'  DSPJOBLOG JOB(...)'` — two invisible characters at the front — and responds with "contains a character that is not valid".

The IBM-documented prototype uses `char(32702)` for the command parameter, not `varchar`. With `char OPTIONS(*VARSIZE) const`, RPG performs an automatic conversion from the `varchar` variable and passes exactly the character data, no length prefix.

[Screenshot — Side-by-side diff showing the QCMDEXC prototype with varchar (wrong) and char (correct)]

I had never run into this specific issue before. I knew the general principle of how `varchar` passes its length prefix internally, but I had not encountered it causing a problem with `QCMDEXC`. Bob knew.

**Option 5 was using the wrong command.**

The initial implementation used `WRKMSG JOB(...)` for Display Messages. `WRKMSG` takes a message queue object path — like `WRKMSG MSGQ(QGPL/QSYSOPR)` — not a job name. It does not accept a `JOB()` parameter. The correct command is `WRKJOB JOB(...) OPTION(*MSG)`, which opens the job's message queue from within the Work With Job interface.

Bob caught this and corrected it. A small thing, but it would have confused operators.

---

## What Surprised Me

A few things stood out during this project.

**The planning step.** I did not expect Bob to produce a structured plan before writing code. I expected it to just generate something. The fact that it reasoned through the design first and then invited me to confirm before proceeding felt like the right way to work.

**The depth on IBM i specifics.** The `varchar`/`char` QCMDEXC issue, the `OVERLAY` 5250 write semantics, the format of `JOB_NAME` in `ACTIVE_JOB_INFO` — these are not things you find by asking a general question. They are things you learn from experience with the platform. Bob had them.

**The targeted edits.** Every time I asked for a change, Bob changed exactly what needed to change. It did not regenerate files it did not need to touch. That matters in practice because you want to understand what changed.

**It was not perfect.** Bob made mistakes. The qualified job name bug, the `QCMDEXC` prototype, the wrong `WRKMSG` command — these were real errors that required correction. The difference was that when I reported a symptom, Bob was able to diagnose the cause correctly and quickly. That is a different thing from being perfect.

---

## The IBM i Services Used

It is worth being specific about which IBM i services Bob selected and why.

**`QSYS2.ACTIVE_JOB_INFO()`** — This is the core data source. It is a table function that returns a real-time snapshot of active jobs. It is SQL-native, so you can filter, sort, and join without CL commands. Bob chose it because the requirement was specifically for real-time job status and this service provides exactly that with minimal overhead.

**`QMHSNDPM`** — The program message send API. Bob used this to route status messages to `*EXT` (the external message queue) and display them via the message subfile on line 24. This is the standard IBM i pattern for interactive program feedback.

**`QCMDEXC`** — The execute CL command API. Bob used this to run the operator actions (HLDJOB, ENDJOB, RLSJOB, DSPJOBLOG, WRKJOB) from within the RPG program. The operator types an option, the program builds the command string, and `QCMDEXC` runs it.

---

## Productivity Comparison

I tracked roughly how long this took and compared it to how long I would have expected it to take doing the work manually.

| Task | Manually | With Bob |
|---|---|---|
| DDS subfile design and layout | 2–3 hours | ~5 minutes |
| RPGLE subfile load and display logic | 3–4 hours | ~10 minutes |
| SQL cursor with ACTIVE_JOB_INFO | 45–60 minutes | Included |
| Message subfile wiring | 1–2 hours | Included |
| Debugging the OVERLAY issue | 30–60 minutes | ~2 minutes |
| Debugging the QCMDEXC varchar/char issue | 1–2 hours | ~5 minutes |
| **Total** | **~2 days** | **< 1 hour** |

The `varchar`/`char` QCMDEXC issue in particular would have cost me significant time. The symptom — "contains a character that is not valid" — gives you almost no information about where the problem is. You end up adding trace code, checking the command string character by character, eventually reading the ILE documentation carefully enough to notice the parameter type issue. Bob knew the cause from the symptom description alone.

---

## What I Learned

**About IBM Bob:**

The value is not just in generating code quickly. It is in having a development partner that understands IBM i well enough to make the right decisions — and diagnose problems at the right level of abstraction.

When Bob fixed the OVERLAY issue, it did not just say "add OVERLAY". It explained that `EXFMT` performs a full-screen write and that without OVERLAY the 5250 data stream clears positions not written by that operation. That explanation is worth more than the fix itself.

**About the Premium Package for IBM i:**

The PPI connection is what makes Bob useful for actual IBM i work. Being able to compile, check output, run SQL queries against live system data — that is what separates this from pasting code into an editor and hoping it compiles. The feedback loop is tight.

**About working with AI on IBM i:**

You still need to know what you are doing. I knew what a subfile was. I knew what `QCMDEXC` was. I knew what MSGW status meant. Without that background, I would not have known whether Bob's plan made sense or whether the generated code was reasonable. Bob accelerated the work. My knowledge shaped the direction.

The right mental model is a development partner, not an oracle. You bring the requirements and the IBM i knowledge. Bob brings speed and recall of platform-specific details. Together you get to a working application faster than either could alone.

---

## Final Thoughts

The application is deployed. It runs on the production IBM i. L1 analysts can open it, see the MSGW jobs, and take action without knowing a single IBM i command.

What I got out of this project was more than the application itself. I got a clearer picture of what AI-assisted development actually looks like in practice on IBM i — not in a demo, but in a real project with real compile errors, real runtime bugs, and real prompt refinements.

If you are an IBM i developer and you have been curious about Bob but not sure where to start, my advice is to pick a project you know well and try it. Not a toy example. Something real. You will learn more from seeing Bob work on a familiar problem than from any demo.

It will not be perfect. There will be things it gets wrong. But it will also know things that surprise you, and it will get you to a working application faster than you expect.

---

*Application details: `BOB4IPGMR/MSGWMON` — compiled SQLRPGLE program, IBM i 7.6*
*Run with: `CALL PGM(BOB4IPGMR/MSGWMON)`*
*Requires `*JOBCTL` special authority for hold, release, and end job actions*

---

*Tags: IBM i · RPG · RPGLE · ILE · DDS · Subfile · IBM Bob · PPI · Developer Mode · Db2 for i · ACTIVE_JOB_INFO*
