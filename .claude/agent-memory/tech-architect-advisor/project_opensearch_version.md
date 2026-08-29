---
name: project-opensearch-version
description: OpenSearch version for fess-suggest is confirmed 3.7.0; TBD-01 (version uncertainty) is closed
metadata:
  type: project
---

fess-suggest / fess (`fess-parent:15.7.0` 系) targets **OpenSearch 3.7.0** (confirmed 2026-07-06). 3.7.0 is a 2026 release.

**Why:** The improvement-proposal docs long treated the OpenSearch/Lucene numeric version as unresolved (**TBD-01 [要確認]**) because `fess-parent` is outside the workspace. The user confirmed it is 3.7.0, closing TBD-01.

**How to apply:** Treat these APIs as available in 3.7.0 (all [事実], not [要確認]): `scripted_upsert`, `script_score`, `function_score`, `rescore`, `knn` (vector/neural, mature plugin), `fuzzy`, Painless. So:
- The `scripted_upsert` caution is about Painless **script complexity**, NOT version availability.
- The MIG-15 staged approach (1st multiGet → 2nd scripted_upsert) is justified by risk/complexity + availability/back-compat value, independent of version.
- Semantic/`knn` remaining unknowns are the **embedding model/inference infra, capacity, latency** — not API availability.
- A "Phase 0 PoC to verify version" is unnecessary; any Phase 0 should be repurposed to performance/feasibility measurement.

**Test infra nuance (confirmed 2026-07-06):** `fess-parent:15.7.0` pins `opensearch.version=3.7.0`, `opensearch.runner.version=3.7.0.0`, `lucene.version=10.4.0`. So `opensearch-runner` IS 3.7.0.0 (version-matched), NOT 2.x. BUT the runner embeds only OpenSearch core — it does **not** bundle the `opensearch-knn` plugin (no knn refs in `opensearch-runner-3.7.0.0.jar`/pom, no knn native libs). => knn PoC/verification must use the full Docker distro `opensearchproject/opensearch:3.7.0` (bundles opensearch-knn + neural-search 3.7.0.0), not the runner. scripted_upsert (core) works on either.

**Verification env (task `20260706_opensearch_reference` step2):** Docker `opensearchproject/opensearch:3.7.0`, single-node, security disabled, heap 1g, host port **9201**, container `os370-verify`. Reusable curl scripts + sample docs live in `agent_docs/tasks/20260706_opensearch_reference/verification/env/` (`healthcheck.sh` = 1-command knn check; `smoke-test.sh` = e2e). Shared indices: `suggest_verify` (scripted_upsert base) / `knn_smoke` (knn base). Step2 already proved knn checklist K3/K4/K5 (index.knn, keyword+vector coexistence, lucene-engine filter).

Applied to `20260629_improvement_proposal_step2` docs on 2026-07-06 (see task `0002-fix-opensearch-version-3.7.0.md`). Related: [[project-improvement-proposal]], [[project-suggest-scoring]], [[project-opensearch-knn-scripted-upsert]].
