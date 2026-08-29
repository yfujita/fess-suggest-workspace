---
name: project-opensearch-knn-scripted-upsert
description: OpenSearch 3.x scripted_upsert/knn doc-research findings & gotchas for fess-suggest redesign (task 20260706_opensearch_reference step1)
metadata:
  type: project
---

Doc-research (2026-07-06) for OpenSearch 3.7.0 `scripted_upsert`/`knn`, backing the fess-suggest redesign (MIG-15 step2 / MIG-24 / E3). Full memo: `agent_docs/tasks/20260706_opensearch_reference/verification/00-docs-research.md`.

Non-obvious findings that shape design (verify against 3.7.0 instance before acting — see [[project-opensearch-version]]):
- **Painless `_scripts/painless/_execute` has NO `update` context** (only painless_test/filter/score). So a scripted_upsert update script cannot be unit-tested via `_execute`; use a throwaway index + real `_update`, or painless_test for pure logic. This corrects the original step-3 plan.
- **knn engine defaults changed nmslib→faiss in 3.0**; nmslib deprecated. `knn` query `filter` works only with faiss/lucene, not nmslib. fess-suggest needs roles/tags filtering → lucene is the leading candidate (good filtering, small-deployment friendly, no separate native memory).
- **3.0 removed index-level knn settings** (`index.knn.algo_param.ef_construction`/`m`, `index.knn.space_type`) → must specify via mapping `method` object. `index.knn:true` still required in settings.
- **scripted_upsert requires both `script` and `upsert`** (upsert can be `{}`). retry_on_conflict = query param (Update) / action meta (Bulk) for concurrency.
- **Hybrid keyword+vector scoring**: use `hybrid` query + Search Pipeline `normalization-processor` (min_max/l2/z_score norm; arithmetic/geometric/harmonic_mean combine; weights sum to 1.0). `neural` sub-query needs a model_id (embedding model, not yet available) → substitute raw `knn` sub-query for IF-only verification.

**Why:** These are gotchas not obvious from the improvement-proposal, which only asserted "3.7.0 で利用可能" without API-level detail.
**How to apply:** Feed these into step 3/4 (impl verification) and step 5 (new schema draft). Prefer lucene engine + method-object mapping; flag dimension/space_type as [要確認] pending the embedding model.
