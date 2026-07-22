You are running one **dream** in the Halvex dream campaign — an unattended scan
for possibilities. Each dream starts from a **technology** (or framework,
standard, protocol, methodology, convention) and discovers how it maps onto this
specific project. Your entire job is to answer ONE question about the topic
below:

> **Would adopting this improve Halvex?**

Judge it against the campaign's benefit lanes — a topic earns its keep by moving
ANY of them, and a strong dream says precisely which:

- **[extraction-accuracy]** / **[extraction-speed]** / **[extraction-cost]** —
  better, faster, cheaper turning of messy filings into correct, evidenced rows
- **[data-accuracy]** — the *stored* data becomes more correct or better evidenced
- **[db-architecture]** — the database becomes more scalable or better structured
- **[earlier-discovery]** — bitcoin-treasury companies are found *sooner*,
  especially small international ones without SEC/EDINET filings
- **[gap-filling]** — a data or coverage hole gets filled
- **[ai-leverage]** — Halvex uses AI better
- **[dev-workflow]** — the owner's Claude Code development workflow improves
- **[new-capability]** — it enables a genuinely different *kind* of capability
  that fits none of the lanes above

This is a **scan for possibilities, not a stress-test.** Explore the *best-case
end-result* if the technology were fully incorporated. **Do NOT weight
implementation difficulty** — assume it gets built well; only judge what the
finished system would be better and worse at. **Be generous:** the topic was
picked without knowing whether it truly fits — you will often be unsure too.
Explore the charitable mapping first and let the evidence push back; a
confident "no, and here is why" is a fine outcome, a timid "maybe" is not.

---

## The topic

- **Index:** {{INDEX}}   **Family:** {{FAMILY_NAME}}
- **Topic:** {{TITLE}}
- **Starting hypothesis** (one prior guess at the mapping — confirm, refute, or
  transcend it; it is a seed, not a boundary): {{HINT}}

**Start from the technology, not from Halvex's problems.** First understand the
technology deeply on its own terms — what it really is, how it works, what its
strongest practitioners do with it — and only then walk it into the project and
see what it touches. The dream should read like an invention: a discovery of how
something maps onto this codebase, not a survey.

## Halvex, in one paragraph

Halvex is a data pipeline that extracts evidence-backed facts about public
companies with Bitcoin on their balance sheet (SEC/EDGAR, Japanese
EDINET/TDnet, Korean DART, ASX, Nordic MFN, per-issuer IR feeds, news) into a
canonical SQLite database (`data/monitor.db`), which a read-only website
projects. It tracks companies across 33 countries on a limited API budget, runs
as unattended TypeScript/Node scripts under systemd timers, and leans heavily on
Claude Code agents. The pipeline surface lives in `scripts/extract/`,
`scripts/ingest/`, `scripts/ir/`, `scripts/edgar/`, `scripts/edinet/`,
`scripts/lib/`, with regression coverage in `tests/`.

## How much work this is

**This dream should take roughly 40–60 minutes of genuine research.** You are not
being scored on speed and nothing is waiting on you — a shallow dream that
finishes in ten minutes is a failed dream. Go wide, then go deep, then do the
real work of applying it to this specific codebase. Use your full effort budget.

Concretely, a dream that has done its job has: swept the topic from **6+ distinct
angles**, **fully read 4–6 primary sources** (actual papers/docs/implementations,
not abstracts or summaries), **read a meaningful slice of the relevant Halvex
code**, and **run several read-only DB queries** whose results appear as numbers
in the write-up. If you have not done all four, you are not finished.

## What to do (one Workflow, four phases)

Use a **single Workflow** for width-then-depth — a substantial but bounded
fan-out (parallel agents per phase, not one agent doing everything serially, and
not a runaway fleet):

1. **Width (~6–8 parallel researchers, each a different angle).** Sweep the
   technology from structurally different directions so no single lens
   dominates: foundational literature/spec, *recent* work and releases (last
   2–3 years), industry and production practice, open-source implementations,
   failure stories / post-mortems / negative results, and adjacent fields that
   use the same technology for a different job. Each returns candidate leads,
   not conclusions.
2. **Depth (parallel deep-reads).** Take the 4–6 most promising leads and read
   them properly — the actual paper, the actual docs, the actual code —
   extracting how the technology really works, what it costs, where it breaks,
   and what it assumes about its inputs. Cite everything you use.
3. **Apply (parallel agents over distinct parts of the codebase).** This is the
   phase that makes the dream worth anything, so give it real time. Read the
   *relevant* parts of the Halvex surface (the directories above, plus `tests/`
   to see what is actually covered) and establish current-state facts by running
   **read-only** queries: `npm run db:query -- --schema` for the shape, then
   `npm run db:query -- --reason "<what you're learning>" "<SELECT …>"` for
   measured reality — coverage gaps, field-population counts, distributions,
   how many rows would actually be affected. Ground every claim in what is
   *there*, not in this prompt. Quote real file paths and real numbers.
4. **Converge.** Write exactly ONE exploration (see output contract), rich enough
   that a reader who knows this codebase learns something concrete from it.

## The second yield: standalone finds

The verdict on the topic is only **half** the job. While researching, actively
**hunt for details inside the topic that help Halvex on their own**, whatever
the overall verdict turns out to be — a sub-technique, an endpoint, a dataset, a
trick, a convention, a companion tool. A zero-value topic verdict with three
good finds is a *successful* dream.

Every find must name a **concrete landing spot in Halvex terms** — an existing
surface (a script, table, or pipeline stage), or an explicit proposal
(`new: <capability>` / `replaces: <existing thing>`). A neat fact with no
landing spot is trivia, not a find. An honest "no standalone finds" is allowed —
but only after actually hunting; never invent filler finds.

## Output contract

Produce **two** things, in this order — the markdown first, so that a failure
while publishing can never cost you the record.

### 1. The durable record (markdown, always)

Write the exploration to **`{{SCRATCH_DREAMS}}/{{NNN}}-{{SLUG}}.md`** with this
header-first shape (so it can be scanned in seconds):

```
# {{TITLE}}

- Topic family: {{FAMILY_NAME}}
- Date: {{DATE}}

**The idea (2 sentences):** <the technology and its mapping onto Halvex, with a
source citation>

**Better at:**
- [extraction-accuracy] …
- [earlier-discovery] …
- [dev-workflow] …   (3–7 bullets total; tag each with the lane it serves)

**Worse at:**
- <honest end-state costs — rigidity, new failure modes, operational burden —
  NOT implementation difficulty>

**Standalone finds:**
- <what it is> → <where it lands: file/table/stage, or new:/replaces:> → <source>
- …   (or: "none found" — after a real hunt)

---

<the body: your research trail, the sources you deep-read, the Halvex code and
DB evidence you gathered, and the full exploration of how the technology maps>
```

### 2. The artifact (build it properly — this is what gets read)

The markdown above is the backup. The **Artifact is the thing that actually gets
read**, often on a phone, so do not just republish the markdown — *build a page*.

**Load the `artifact-design` skill first** (required before writing any HTML
page), then author a self-contained HTML page at
**`{{SCRATCH_DREAMS}}/{{NNN}}-{{SLUG}}.html`** and publish it with the Artifact
tool (favicon `💭`, plus a one-sentence description for the gallery card).

You have **real latitude in how you present this** — use whatever structure
serves the specific idea: comparison tables, a mermaid diagram of the proposed
pipeline versus the current one (mermaid renders natively in artifacts),
before/after code or SQL snippets, callouts for the measured numbers you found,
a small visual for the benefit lanes. Judge the presentation by whether a reader
who knows this codebase grasps the idea faster than they would from prose.

Two constraints only:

- **Lead with the scannable header** — title, the 2-sentence idea, then
  *Better at*, *Worse at*, and *Standalone finds* — above the fold, before any
  body. These pages get triaged in seconds; the verdict must never be buried.
- **Self-contained**: inline all CSS/JS, no external fonts/CDNs/images (a strict
  CSP blocks them), theme-aware for light and dark, and no horizontal page
  scroll on a phone.

Do not let the page-building eat the research budget — the research is the
substance, the artifact is how it lands. If publishing fails for any reason, the
markdown still stands; record the failure in result.json and move on.

### 3. The machine-readable result

**Write `{{SCRATCH_DREAMS}}/{{NNN}}.result.json`** with exactly:

```
{"artifact_url": "<url>", "title": "{{TITLE}}",
 "idea": "<the 2-sentence idea>",
 "better": ["<bullet>", …], "worse": ["<bullet>", …],
 "finds": [{"what": "<the detail>", "where": "<landing spot>", "source": "<citation>"}, …]}
```

(use `"artifact_url": ""` if publishing failed; `"finds": []` if the hunt came
up honestly empty).

## Hard rules

- You may write ONLY under `data/scratch/`. Everything else is read-only; a
  write-jail hook will refuse anything outside it.
- Never touch git, systemctl, deploys, or the database's contents. `db:query`
  is read-only in this context — keep it to SELECTs.
- Work in the current directory. Do not create or enter git worktrees.
- Do not ask questions — there is no one to answer. Make the call and record it.
- If, after honest research, the topic earns nothing for Halvex, say so plainly
  in the exploration (a zero-value dream is a legitimate, useful outcome). Still
  write the markdown, publish the artifact, and write result.json.
