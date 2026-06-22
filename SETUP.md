# RCA/RCB RAG Framework — Setup & Repeatable Workflow

This is the operating manual for the knowledge framework. It covers one-time setup
and the **ongoing process you repeat** for every new org/project and every time the
knowledge base grows. (Architecture/commands reference: [rag/README.md](rag/README.md).)

The framework answers questions about Salesforce **Revenue Cloud Advanced (RCA)**
and **Revenue Cloud Billing (RCB)**, grounded in official docs + a connected org.
**Salesforce CPQ / legacy "Salesforce Billing" is excluded.** Nothing is retrained:
you grow the **knowledge base** (text files), the model just looks things up.

---

## 1. One-time setup (per machine)

This framework is **local-first — no Claude required.** Two local pieces:

```bash
pip install -r requirements.txt
pip install sentence-transformers     # local embeddings (on-device, no tokens)
```

**Local LLM (default — for synthesized answers with no API/tokens):** install
[Ollama](https://ollama.com), then pull a model:

```bash
ollama pull llama3.1                   # or any model; set it in config/model.yaml
```

That's it — `config/model.yaml` already points `llm.provider: local` at Ollama
(`http://localhost:11434/v1`). Nothing leaves your machine.

> Without a local LLM running, the system still works in **"extractive" mode**
> (returns the grounded source chunks with citations) — it just doesn't *write*
> prose answers. Retrieval, tagging, scope, eval, and the chat window all work.

**Optional — Claude instead of a local model.** Only if you *want* Claude to write
answers: set `llm.provider: anthropic` in `config/model.yaml` and export
`ANTHROPIC_API_KEY`. This is off by default; the framework never calls Claude
unless you switch to it.

Edit `config/scope.yaml` to change what counts as RCA/RCB/CPQ — never the code.

---

## 2. The repeatable workflow

### A. Onboard a new org/project

```bash
python -m rag new-project <orgname>        # creates projects/<orgname>/{metadata,reference}
```

Then pull that org's metadata into `projects/<orgname>/metadata/` (e.g.
`sf project retrieve start -o <alias> -m "CustomObject:Product2,..."`), and fill in
`projects/<orgname>/reference/00-org-bible.md` (the 4-section Org Bible). Verify
every claim against the live org before writing it down — do not invent.

### B. Add product knowledge (RCA/RCB)

Drop text/markdown into the right `knowledge/rca-rcb/` folder:

| Folder | Put here |
|---|---|
| `docs/` | Official RCA & RCB documentation (the product source of truth) |
| `release-notes/` | One file per Salesforce release |
| `patterns/` | Discovered patterns & gotchas |
| `corrections/` | Explicit fixes when the assistant answered wrong |
| `qa/` | Curated Q/A pairs — these are also the eval/regression set |

### B2. Pull org metadata (per project)

Turn the org's component metadata into ingestible field references:

```bash
python -m rag pull-metadata --retrieve   # run RetriveRCAMeta.txt sf retrieves, then summarize
python -m rag pull-metadata --all        # mirror every object in force-app + prune removed ones
```

This writes `projects/<project>/metadata/<Object>.md` (field name/type/label/refs).
**Adds and removals are handled automatically:** new components produce new docs,
field changes rewrite the doc, and removed components have their stale docs pruned
— all of which flow into the index on the next step.

### C. Index (incremental — only changed files are re-embedded)

```bash
python -m rag index
```

`index` is content-hash incremental: it embeds new files, re-embeds changed ones,
and **drops removed ones** — so anything added or removed since last run is picked
up. Use `--rebuild` only after changing the embedder or tagging rules.

### D. Ask

```bash
python -m rag query "What selling models are configured?"
python -m rag query "How many active products are there right now?" --live
```

Or use the **interactive chat window** (runs on localhost, keep it open):

```bash
python -m rag serve                 # open http://127.0.0.1:8000
python -m rag serve --port 9000 --live
```

The window has a "live org" toggle per message and shows citations under every
answer. It uses the exact same grounded pipeline as `query`.

### E. Guard against regressions

Add a Q/A pair to `knowledge/rca-rcb/qa/` for anything important, then:

```bash
python -m rag eval        # fails (nonzero exit) if any answer regresses
```

---

## 3. The improvement loop (how it "keeps learning")

1. Ask a question.
2. If the answer is wrong or thin → write the fix into `knowledge/rca-rcb/corrections/`
   (and/or fix the underlying doc), and add a Q/A pair to `qa/` so it can't regress.
3. `python -m rag index` → `python -m rag eval`.
4. New Salesforce release → add a file to `release-notes/` and re-index.

No retraining, ever. The model stays fixed; the knowledge base is what improves.

---

## 3b. Reuse for the next RCA project (the framework is portable)

The system is split into a **reusable core** and **per-project** parts, so each new
RCA engagement starts from the accumulated knowledge instead of scratch.

**Reusable core — carry these to every new RCA project:**
- `rag/` — the engine (ingest/retrieve/answer/tools/CLI).
- `config/scope.yaml`, `config/model.yaml` — scope + model selection.
- `knowledge/rca-rcb/` — RCA/RCB product docs, patterns, corrections, and the
  `qa/` eval set. **This is the compounding asset**: every doc, gotcha, correction,
  and Q/A you add benefits all future projects.
- `knowledge/salesforce-standard/` — standard out-of-the-box knowledge.

**Per-project — regenerated for each org (not carried over):**
- `projects/<org>/` — that org's Org Bible + metadata field summaries.
- `force-app/` — that org's metadata (the Salesforce repo itself).
- `index/` — rebuilt locally with `index`.
- `ORG`-tagged content — that org's Apex/flows/LWC/config.

**Starting the next RCA project:**
1. Start from this framework (clone it, or keep a template repo of the reusable core).
2. `python -m rag new-project <neworg>`.
3. Connect `sf` to the new org and refresh its metadata into `force-app/` (you do this).
4. `python -m rag pull-metadata --all` then `python -m rag index`.
5. Fill `projects/<neworg>/reference/00-org-bible.md`, add org-specific Q/A to `qa/`.

The RCA/RCB knowledge and the engine come along automatically; only the org-specific
layer changes.

## 4. Scope rules (enforced automatically at ingest)

- Every chunk is tagged from `config/scope.yaml`. `"Revenue Cloud Billing"` → RCB
  (kept); bare `"Salesforce Billing"` → CPQ (dropped).
- A chunk mentioning both an included and an excluded product → `MIXED`: logged to
  `index/review.log` and excluded from retrieval. Check that log periodically.
- Retrieval returns only RCA/RCB chunks. CPQ, MIXED, and untagged content never
  reach the answer.

---

## 5. Swapping the model later (e.g. to a self-hosted open model)

Edit `config/model.yaml` only:
- `llm.provider`: `anthropic` (Claude) → your self-hosted provider.
- `embeddings.provider`: `local` (on-device, free) / `voyage` / `hashing`.

No other code changes. The whole framework — ingestion, tagging, retrieval, eval —
is model-agnostic, so you can validate on Claude now and move to a free self-hosted
model later to eliminate per-query token cost.

---

## 6. Acceptance checks (sanity test after changes)

```bash
python -m rag index      # empty knowledge folder still succeeds + writes manifest
python -m rag eval       # empty qa folder reports "0 tests" cleanly
# add one RCA doc + one CPQ doc, index, query -> RCA content returned, CPQ never
```
