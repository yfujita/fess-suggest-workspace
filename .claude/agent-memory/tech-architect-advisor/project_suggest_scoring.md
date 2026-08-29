---
name: project-suggest-scoring
description: fess-suggest scoring is single-system (search-time function score); the precomputed score field is dead-written and never read
metadata:
  type: project
---

fess-suggest ranking is governed solely by search-time function score, not by the precomputed `score` field.

**Fact (verified 2026-06-22, code may drift — re-grep before acting):**
- Search: `SuggestQueryBuilder.buildFunctionScoreQuery` evaluates DOC_FREQ/QUERY_FREQ (LOG2P modifier) + USER_BOOST + prefix weight at query time. Does NOT read the `score` field.
- Popular words: `PopularWordsRequest.buildQuery` uses QUERY_FREQ factor + random rescorer. Does NOT read `score`.
- The precomputed `score = (queryFreq+docFreq)*userBoost` is written in 4 places (`SuggestItemSerializer`, `SuggestItem`, `SuggestUtil`) and mapped as `double`, but never read/sorted/queried → effectively a dead field.

**Why it matters:** Earlier analysis framed this as a confusing "two scoring systems." The accurate framing is "one live system + one dead field." Any scoring-change proposal should account for this (either drop the dead field, or repurpose it for sort to cut query-time cost — a perf vs freshness tradeoff).

**Other verified mechanics:**
- `suggestDetail` defaults to `true` (`SuggestRequest` field initializer); builder/handler never override → fess `SuggestWordsHandler` safely relies on `items`. Risk is implicit-default coupling, not "undetermined."
- bad-word has TWO partial-match mechanisms (verified 2026-07-02): (1) ingest-time filter `SuggestItem.isBadWord` uses Java `text.contains(badWord)` — non-destructive, just skips indexing the new item; (2) registration-time `WordManagementOperations.addBadWord(apply=true)` issues `wildcardQuery(TEXT, "*word*")` deleteByQuery — destructive, irreversible physical delete of existing docs. Both partial-match, but matcher is duplicated (`contains` vs `wildcard` — the latter interprets `*?` metachars, so they can diverge). Key reconciliation for the step2 proposal: partial match is the INTENDED behavior per user requirement; the real ISS-04 problem is irreversibility + matcher duplication, NOT the partial matching. Fix = unify into single BadWordPolicy (keep partial) + make reversible (logical `excluded` flag / defer purge to rebuild) + dry-run.
- Merge rules are duplicated across `SuggestItemMerger.merge` (object-to-object) and `SuggestItemSerializer.toUpdatedSource` (item-to-OpenSearch-map) with asymmetric reading-traversal bases.
- Indexing is Get-then-update: `SuggestIndexWriter` does a per-item synchronous Get (not multiGet) then one bulk → N gets + 1 bulk.

See [[project-improvement-proposal]] for the task that produced these findings.
