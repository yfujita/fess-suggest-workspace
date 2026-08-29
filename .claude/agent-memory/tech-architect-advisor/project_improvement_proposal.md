---
name: project-improvement-proposal
description: Context for the 20260622_improvement_proposal task — a major-version-up improvement proposal for fess-suggest, doc layout and step structure
metadata:
  type: project
---

Task `20260622_improvement_proposal`: produce a major-version-up ("抜本的改善") proposal for fess-suggest. Output is a proposal, not implementation.

**Why:** fess-suggest code has grown complex (needs high Java skill to maintain), suggest quality is mediocre, features unchanged for 10+ years. Five evaluation axes: readability / changeability / suggest quality / performance / new features.

**How to apply:** Treat code investigation as root-cause/grounding for proposals, kept minimal — do not exhaustively read all code; reuse the prior analysis under `agent_docs/global/references/legacy/` (01-overview..05-issues) rather than re-investigating.

**Doc layout** (`agent_docs/tasks/20260622_improvement_proposal/`):
- `0000-requirements-definition.md` — requirements + 5 axes
- `0001-work-plan.md` — plan; step3 splits 3-1 (To-Be arch, main) + 3-2..3-7 (axis cross-checks)
- `0002-step1-issue-inventory.md` — issue inventory ISS-01..17, TBD-01..05. Axis coverage (§6): readability=01,02,03,05,06,13,14,16,17 / changeability=01,02,03,04,05,06,09,13,15,17 / quality=04,05,10,11,12,14,15 / perf=07,08,09,10,16 / new-features=11,12
- `0003-step2-codebase-verification.md` — code verification backing ISS-03/04/05/10/13/14, new ISS-16/17
- `0005-step3-1-to-be-architecture.md` — To-Be arch (MAIN). Sections: §3 use-split public API, §4 SuggestSource抽象, §5 TextProcessor pipeline(踏襲), §6 index/schema, §7 write/aggregate, §8 sync/async, §9 ScoringStrategy/word-mgmt, §10 AuthorizationFilter, §11 reuse assets. §4.2/§9.2/§5.2 explicitly reserve hooks "新機能(3-6)はここに載る"
- `0006`=3-2 readability, `0008`=3-3 changeability, `0009`=3-4 quality (Q1-Q5), `0010`=3-5 performance (P1-P5), `0011`=3-6 new-features (E1-E5 extension points)
- `0007-add-step3-7-google-comparison.md` — note adding step 3-7 (Google comparison); 3-7 doc itself not yet produced as of 2026-06-27

**Sibling doc format (0009/0010/0011)**: §0 位置づけ/凡例([事実]/[提案]/[要確認])/カバレッジ → axis定義(Q/P/E軸) → 各設計判断×軸 → ISS対応表 → MECE点検 → 役割分担 → 残課題. Each axis doc is "internal-ISS-起点" except 3-7 (Google起点). 3-6=新機能を設計に内包する立場.

Convention: work-history docs are mandatory (CLAUDE.md); sequential number = max existing + 1, 4-digit. Distinguish [確認] (code-verified) vs [推測] (inferred) in all docs.

Verified suggest mechanics live in [[project-suggest-scoring]].
