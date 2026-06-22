# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Salesforce DX project tracking the metadata of a **Revenue Cloud Advanced (RCA)** org. It is not a standalone app — code here is deployed to / retrieved from a live Salesforce org. All source lives under the single default package directory `force-app/main/default/`, organized by metadata type (`classes/`, `triggers/`, `lwc/`, `aura/`, `flows/`, `objects/`, `flexipages/`, `permissionsets/`, etc.).

Despite being one org, it contains several **independent business domains** that share infrastructure but are otherwise unrelated. Identify which one you're touching before changing shared classes:
- **RPRF** — Resource Planning & Revenue Forecasting (`RPRF*`, `Daily_Assignment__c`, `SFDC_Resource__c`, `SFDC_Projects__c`, `SFDC_Assignment__c`, `Allocation__c`)
- **Time tracking** — `Timecard*`, `Timesheet*`, `DCS*`, `Time_Entry__c`, `Timecard_Summary__c`
- **Soft Validation** — a custom rule-evaluation framework (`SoftValidation*`, `SoftValidationRule__c`)
- **Migration tools** — Attachments→Files (`ATF*`), Notes (`NMT*`), Notes & Attachments (`NAM*`); these are self-contained batch/controller utilities
- **Estimator / Revenue / Billing** — `Project_Estimate*`, `Revenue__c`, `Project_Monthly_Billing_Milestones__c`

## Common commands

This repo's npm scripts only cover the JS/LWC tooling. Org operations use the Salesforce CLI (`sf`) directly.

```bash
# LWC unit tests (Jest via sfdx-lwc-jest)
npm run test:unit                  # all LWC tests
npm run test:unit:watch
npm run test:unit:coverage
npx sfdx-lwc-jest -- <path-or-name> # run a single LWC test bundle

# Lint & format
npm run lint                       # eslint over aura + lwc JS
npm run prettier                   # format (Apex via prettier-plugin-apex, XML via plugin-xml)
npm run prettier:verify

# Deploy / retrieve (target org alias is "ascendsandbox", set in .sf/config.json)
sf project deploy start  -d force-app/main/default/classes/SomeClass.cls
sf project retrieve start -d force-app/main/default/...
sf project deploy start  -x manifest/package.xml        # full-org manifest

# Apex tests run on the org (there is no local Apex test runner)
sf apex run test --tests SoftValidationRuleHandlerTest --result-format human
sf apex run test --class-names RPRFResourceServiceTest
sf apex run --file scripts/apex/hello.apex              # anonymous Apex
sf data query --query "SELECT Id FROM Account LIMIT 1"
```

A Husky `pre-commit` hook runs `lint-staged`: Prettier on all supported files, ESLint on aura/lwc JS, and `sfdx-lwc-jest --findRelatedTests` on changed LWC.

> Note: `sfdx-project.json` declares `sourceApiVersion` 66.0 while `manifest/package.xml` is pinned at 64.0 — keep that in mind when a deploy's API version matters.

## Apex test conventions

Test classes use **two** naming conventions inconsistently — match the neighbor of the class you're editing: `<Class>Test` (newer, e.g. `RPRFResourceServiceTest`) and `<Class>_UT` (older, e.g. `ctrlTimecardEntry_UT`). Most non-test classes name their test in a header comment (`// Test Class: ...`).

## Architecture patterns

### Triggers — three coexisting styles
There is no single enforced trigger framework. When editing a trigger, follow the style already used by that object:
1. **Direct static handler calls** — `AccountTrigger` calls `AccountHandler.someMethod(Trigger.new, ...)` inline. Most common.
2. **`AbstractTrigger`** — a `virtual` base class whose `execute()` dispatches to overridable `beforeInsert`/`afterUpdate`/etc. and has a global `AbstractTrigger.Disabled` kill-switch.
3. **`ITrigger`/bulk handler** (classic dataforce-style) — used by `SoftValidationRuleTrigger` → `SoftValidationRuleHandler`, with `bulkBefore()`/`bulkAfter()`, per-record `beforeInsert(so)`/`afterUpdate(old,new)`, and `andFinally()`.

### LWC → Apex bridge (the dynamic-dispatch convention)
Most newer LWC don't import `@AuraEnabled` methods directly. Instead they call a single generic entry point:

- `lwc/utilities/apex.js` exposes `Apex.invoke(handler, action, params)`, which calls `BaseController.auraInvoke({handlerName, actionName, params})`.
- `BaseController.auraInvoke` does `Type.forName(handlerName).newInstance()`, casts to **`Callable`**, and calls `instance.call(actionName, params)`, wrapping the result in `AuraHelper.Response` (`{result}` or `{error}`).
- Controllers implementing this (e.g. `RPRFResourcePlanningController`, `RPRFAssignmentService`, `AbstractLookupController`) dispatch on `actionName` via a `switch on` inside their `call()` method.

So to add a server action for these components: add a `when '<action>'` branch to the controller's `call()` method — **not** a new `@AuraEnabled` method. Exceptions exist: some LWC (e.g. `softValidation`) still import `@AuraEnabled` methods directly from their controller (`SoftValidationController`). Check the component's `.js` imports first.

### Shared infrastructure classes
- **`SObjectService`** — `without sharing` singleton (`getInstance()`) for generic SOQL/DML by object name and field set; the common data-access layer.
- **`AuraHelper`** — `Response` wrapper and `AuraException` used across the `auraInvoke` path.
- **`BaseController`** — the `auraInvoke`/`remoteInvoke` (`@RemoteAction`) entry point described above.

## MCP org access
`.mcp.json` wires the `salesforce` MCP server to the `ascendsandbox` org (`--toolsets all`). Two org connections are also available as MCP tools in-session: **Ascend_Sandbox** and **RCA_Org** (SOQL, schema describe, CRUD). Use these to inspect live org data/schema rather than guessing field names from metadata XML.

## RCA/RCB RAG Assistant Framework (`rag/`)

This repo also contains a **local, config-driven RAG assistant** that answers
questions about Salesforce Revenue Cloud Advanced (RCA) and Revenue Cloud Billing
(RCB), grounded in official docs + this org. **CPQ is excluded.** It is the
foundation of a reusable framework for future RCA projects. Full guide: `SETUP.md`
and `rag/README.md`.

- **Runs fully local — no Claude required.** Embeddings = on-device
  `sentence-transformers` (MiniLM). LLM = local Ollama by default
  (`config/model.yaml`); without an LLM it answers in "extractive" mode (grounded
  chunks + citations). Claude is opt-in only.
- **Commands:** `python -m rag {index | query | eval | serve | new-project | pull-metadata}`.
  `serve` is the interactive localhost chat window (loads the model once, then
  ~0.3s/query). `index` is incremental (content-hash); add/remove of files/components
  auto-propagates.
- **Knowledge base:** `knowledge/rca-rcb/` (docs/patterns/corrections/qa — reusable
  across projects), `knowledge/salesforce-standard/` (out-of-the-box, `SF` tag),
  `projects/<org>/` (per-org Org Bible + metadata field summaries). The org's full
  metadata (Apex/flows/LWC/config under `force-app/`) is ingested under the `ORG` tag.
- **Scope is data, not code:** product aliases + include/exclude live in
  `config/scope.yaml` (RCA/RCB/SF/ORG included, CPQ excluded; folder-based tagging).
- **`--live`** gives the model read-only org tools (`soql_query`, `tooling_query`,
  `describe_object`, `list_metadata`) via the `sf` CLI.
- **Reusable core vs per-project:** carry `rag/` + `config/` + `knowledge/` to the
  next RCA project; regenerate `projects/<org>/`, `force-app/`, `index/`. See
  `SETUP.md` §3b.
- **Do NOT run `sf` metadata retrieves** — the user refreshes the org themselves;
  only run local `pull-metadata` (summarize) + `index`.
