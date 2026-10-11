# Backlog: nathanmcnulty/azd-myworkid

> Generated from `docs/backlog.json`. Edit the JSON source and regenerate this file.
> Standard: [azd agent backlog standard](https://github.com/nathanmcnulty/azd-reference/blob/main/standards/agent-backlogs.md). This link is review guidance, not a runtime dependency.

- **Schema version:** 1.0.0
- **Repository:** nathanmcnulty/azd-myworkid
- **Source revision:** `1ab0e84aeda2a5e5bccd0e4b2dc4bc828dcbf4ec`
- **Captured:** 2026-10-04
- **Items:** 7

## MWID-001: Reconcile this backlog with current source and active work

- **Kind:** discovery
- **Priority:** P1
- **Status:** done
- **Wave:** 0
- **Authorization:** local-only
- **Blocker:** _none_
- **Claim:** _none_

**Problem:**

Plans and implementation evidence are spread across files; the captured source can change while other tasks work.

**Scope:**

- docs/backlog.json
- docs/backlog.md
- Existing roadmap, execution status, open issues and pull requests &lpar;read-only&rpar;

**Acceptance:**

- Classify each candidate as implemented, still open, superseded or awaiting evidence; retain source links and reasons.
- Inspect dirty state, remotes, worktrees and local environment presence without reading secrets; avoid duplicate work with active owners.
- Resolve the actual offline validation commands and record exact current default-branch/working-tree provenance; do not copy historical live passes to newer code.

**Validation:**

- git status --short
- git remote -v
- git worktree list --porcelain
- Read the applicable instructions and validation workflow; read gh issue list and gh pr list for the named repository using nathanmcnulty. Do not create or modify issues/PRs.

**Dependencies:**

- _none_

**Components:**

- _none_

**Sources:**

- README.md
- https&colon;//github.com/nathanmcnulty/azd-myworkid/pull/33
- https&colon;//github.com/nathanmcnulty/azd-myworkid/pull/31
- https&colon;//github.com/nathanmcnulty/azd-myworkid/pull/29
- https&colon;//github.com/nathanmcnulty/azd-myworkid/pull/36
- https&colon;//github.com/nathanmcnulty/azd-myworkid/pull/39

**Evidence:**

- Reconciled against current main 1ab0e84aeda2a5e5bccd0e4b2dc4bc828dcbf4ec in a clean worktree. Issues &num;35 and &num;34 are closed by merged PRs &num;36 and &num;39. PRs &num;29, &num;31, &num;33, &num;37 and &num;38 remain open Dependabot updates. The canonical permission-tracking checkout was preserved; no .azure or .env path was present.
- Current-base dotnet restore and Release build passed with zero warnings/errors. This host lacks the required ASP.NET Core 8 runtime, so the exact net8 testhost could not start. A clearly labeled major-roll-forward probe passed 22/22 unit tests but was not acceptance-equivalent&colon; 62 of 72 integration tests failed under ASP.NET Core 10 with PipeWriter API incompatibility. PR &num;39 CI evidence remains the exact-runtime 22 unit/72 integration result; the local runtime gap is retained rather than hidden.

**Review and authorization note:**

Review MWID-001 against the current repository state. Its status or authorization class is not eligible for an actionable generated handoff. Do not claim or execute it without explicit selection, satisfied dependencies, and every required authorization. Never interpret this generated view as approval.

## MWID-004: HTTP transport failure is masked by a null response dereference

- **Kind:** discovery
- **Priority:** P1
- **Status:** done
- **Wave:** 0
- **Authorization:** local-only
- **Blocker:** _none_
- **Claim:** _none_

**Problem:**

Open report captured 2026-10-03 during execution reconciliation. Another code-quality task may own an active fix; inspect its PR and current source before dispatch.

**Scope:**

- Linked issue and current source &lpar;read-only&rpar;
- Repository-local backlog evidence

**Acceptance:**

- Read the linked issue and current default branch; classify the exact defect, current owner and evidence gap.
- Record a current PR or verified resolution before selecting any implementation; preserve broader feature and live acceptance gates.

**Validation:**

- Read current issue and PR state using nathanmcnulty; do not modify or close issues during reconciliation.
- Inspect dirty state and worktrees; resolve the exact current revision and relevant offline commands before implementation.

**Dependencies:**

- _none_

**Components:**

- _none_

**Sources:**

- https&colon;//github.com/nathanmcnulty/azd-myworkid/issues/35
- https&colon;//github.com/nathanmcnulty/azd-myworkid/pull/36

**Evidence:**

- Issue &num;35 is fixed by merged PR &num;36 at f91295b3f3cb25c3858f1b273761506406c6bf31&colon; VerifiedIdService.cs preserves the original transport exception when no HTTP response exists and its unit test covers the trigger. The PR reports 19 .NET 8 unit and 69 integration tests; the CodeQL check-name repair is separate workflow scope.

**Review and authorization note:**

Review MWID-004 against the current repository state. Its status or authorization class is not eligible for an actionable generated handoff. Do not claim or execute it without explicit selection, satisfied dependencies, and every required authorization. Never interpret this generated view as approval.

## MWID-005: Require authenticated identity for Verified ID SignalR subscriptions

- **Kind:** discovery
- **Priority:** P1
- **Status:** done
- **Wave:** 0
- **Authorization:** local-only
- **Blocker:** _none_
- **Claim:** _none_

**Problem:**

Open report captured 2026-10-03 during execution reconciliation. Another code-quality task may own an active fix; inspect its PR and current source before dispatch.

**Scope:**

- Linked issue and current source &lpar;read-only&rpar;
- Repository-local backlog evidence

**Acceptance:**

- Read the linked issue and current default branch; classify the exact defect, current owner and evidence gap.
- Record a current PR or verified resolution before selecting any implementation; preserve broader feature and live acceptance gates.

**Validation:**

- Read current issue and PR state using nathanmcnulty; do not modify or close issues during reconciliation.
- Inspect dirty state and worktrees; resolve the exact current revision and relevant offline commands before implementation.

**Dependencies:**

- _none_

**Components:**

- _none_

**Sources:**

- https&colon;//github.com/nathanmcnulty/azd-myworkid/issues/34
- https&colon;//github.com/nathanmcnulty/azd-myworkid/pull/39

**Evidence:**

- Issue &num;34 is fixed by merged PR &num;39 at current main&colon; VerifiedIdHub requires authentication, registers and disconnects by validated user object ID, the client reuses its backend Access-scope token, and query tokens are accepted only on the exact hub path. The PR reports 22 unit and 72 integration tests plus frontend build, including cross-user routing isolation; actual tenant browser/WebSocket acceptance remains unverified.

**Review and authorization note:**

Review MWID-005 against the current repository state. Its status or authorization class is not eligible for an actionable generated handoff. Do not claim or execute it without explicit selection, satisfied dependencies, and every required authorization. Never interpret this generated view as approval.

## MWID-006: Apply compatible client security dependency updates

- **Kind:** maintenance
- **Priority:** P1
- **Status:** done
- **Wave:** 1
- **Authorization:** local-only
- **Blocker:** _none_
- **Claim:** _none_

**Problem:**

The client lockfile retains available security fixes in Axios, AJV, brace-expansion, source-map-js and the Sass watcher dependency path.

**Scope:**

- src/MyWorkID.Client/package.json
- src/MyWorkID.Client/package-lock.json
- docs/backlog.json
- docs/backlog.md

**Acceptance:**

- Resolve available fixes within existing dependency major versions and verify complete platform watcher siblings and registry integrity.
- Run a fresh locked install and production client build; record the exact resulting audit findings without claiming all vulnerabilities resolved.
- Preserve unrelated source and existing backlog records; obtain independent review and exact-head hosted checks before publication.

**Validation:**

- npm ci --ignore-scripts --no-fund --audit=false
- npm run build
- npm audit --json
- Validate canonical backlog schema/render and independently inspect the exact lockfile diff.

**Dependencies:**

- _none_

**Components:**

- _none_

**Sources:**

- src/MyWorkID.Client/package.json
- src/MyWorkID.Client/package-lock.json
- https&colon;//github.com/nathanmcnulty/azd-myworkid/pull/38
- https&colon;//github.com/nathanmcnulty/azd-myworkid/pull/37

**Evidence:**

- Compatible client fixes published via merged https&colon;//github.com/nathanmcnulty/azd-myworkid/pull/46&colon; reviewed head 22d469514c187327bb78895d5fc0a41443e6cd72 and main 090c4d4da64d4e8a0e4a9d0630bf980059812de9 have equal Git tree 3f5d031ce72d15f1e029320f5394dfbdc7534fd5. Axios 1.20.0, AJV 6.15.0, brace-expansion 1.1.21/2.1.7, source-map-js 1.2.2 and compatible @parcel/watcher 2.6.0/matching platform siblings are independently reviewed with exact upstream registry integrity. Upstream watcher no longer declares win32-ia32; removal of its stale lock entry is metadata reconciliation, not platform execution acceptance.
- Independent validation of exact frozen client bytes&colon; fresh npm ci --ignore-scripts --no-fund --audit=false and npm run build passed; PowerShell 7.6.6, Node 26.7.0, npm 11.19.0. npm audit reports nine high vulnerable entries through remaining unpatched braces, zero moderate/critical/low. This is bounded available-compatible-fix completion, not a security all-clear. MWID-007 retains the separate blocked advisory/path decision; MWID-002 retains live setup acceptance. No tenant/browser authentication or Linux/macOS/ia32 execution is claimed.
- Source freeze 6093C4EFD9F2C552145BB79CF76DC05A339B985F752EE8D146A21FD46D2A8ED7; independent review PASS 16601FD55459B2BA449B21347C20C95C8BDA719E6BFE0D58BF703767ECDE7117. All six exact PR-head checks passed &lpar;CodeQL 38119037184, dependency review 38119037376, Test CI 38119037171&rpar;; both exact main checks passed &lpar;CodeQL 38119255950, Build Binaries 38119255946&rpar;. Published integration receipt SHA256 80AC0A8AE87CD3EA363AF9A4706BDC41684DC8406C12991BAF101ECF3A1BA4EA records equal source/main trees and preserved reviewed source branch.

**Review and authorization note:**

Review MWID-006 against the current repository state. Its status or authorization class is not eligible for an actionable generated handoff. Do not claim or execute it without explicit selection, satisfied dependencies, and every required authorization. Never interpret this generated view as approval.

## MWID-007: Resolve remaining braces dependency advisory after an available fix

- **Kind:** maintenance
- **Priority:** P1
- **Status:** blocked
- **Wave:** 1
- **Authorization:** local-only
- **Blocker:** No fixed braces release currently published; reassess compatible remaining dependency paths before choosing a major tooling migration.
- **Claim:** _none_

**Problem:**

The current braces 3.0.3 release remains affected by GHSA-vfj7-8cjw-p6xm; client lint and glob dependencies still transitively depend on it.

**Scope:**

- src/MyWorkID.Client/package-lock.json
- src/MyWorkID.Client/package.json
- docs/backlog.json
- docs/backlog.md

**Acceptance:**

- Check for a published fixed braces release or a compatible dependency path replacement using current registry and advisory evidence.
- Keep any necessary major tooling migration a separately reviewed change; verify actual lint/build behavior rather than forcing audit fixes.
- Record exact remaining audit and dependency paths, distinguishing build tools from shipped browser code without inferring absence of impact.

**Validation:**

- npm audit --json
- Inspect npm dependency paths and current registry release metadata.
- Run a fresh locked install and production build for any proposed repair.

**Dependencies:**

- MWID-006

**Components:**

- _none_

**Sources:**

- https&colon;//github.com/advisories/GHSA-vfj7-8cjw-p6xm
- https&colon;//registry.npmjs.org/braces/latest

**Evidence:**

- Current registry lookup during this change reports braces 3.0.3 as latest. The separate compatible watcher update removes one path; the remaining advisory must stay visible and is not resolved by package metadata or a successful client build.

**Review and authorization note:**

Review MWID-007 against the current repository state. Its status or authorization class is not eligible for an actionable generated handoff. Do not claim or execute it without explicit selection, satisfied dependencies, and every required authorization. Never interpret this generated view as approval.

## MWID-002: Qualify package, domain, authentication-context and optional Verified ID paths

- **Kind:** verification
- **Priority:** P1
- **Status:** proposed
- **Wave:** 2
- **Authorization:** tenant-write
- **Blocker:** _none_
- **Claim:** _none_

**Problem:**

The deployed published package still depends on tenant-specific CA, DNS, certificate and credential setup.

**Scope:**

- docs/
- scripts/
- infra/

**Acceptance:**

- Verify pinned package provenance and safe resume after DNS/certificate propagation.
- Record auth-context/CA configuration and optional Verified ID issuance/presentation outcomes under exact authorization.
- TAP values, tokens and recovery secrets remain outside logs; preserve unrelated applications/domains on cleanup.

**Validation:**

- Use the offline commands in the registered validation workflow; record the exact commands, revision and results before implementation is complete.
- Run focused tests for changed behavior from tests/; fixtures do not prove live-service or endpoint behavior.
- After separate authorization, retain redacted exact-target live evidence and cleanup results outside public Git. Do not execute live operations from this backlog alone.

**Dependencies:**

- _none_

**Components:**

- _none_

**Sources:**

- README.md
- AGENTS.md

**Evidence:**

- _none_

**Review and authorization note:**

Review MWID-002 against the current repository state. Its status or authorization class is not eligible for an actionable generated handoff. Do not claim or execute it without explicit selection, satisfied dependencies, and every required authorization. Never interpret this generated view as approval.

## MWID-003: Add resumable feature status with bounded deployment validation

- **Kind:** feature
- **Priority:** P2
- **Status:** done
- **Wave:** 2
- **Authorization:** local-only
- **Blocker:** _none_
- **Claim:** _none_

**Problem:**

Administrators need to distinguish provisioning success from pending DNS, certificates and optional tenant setup.

**Scope:**

- scripts/
- docs/
- azd-components.lock.json
- azd-permissions.json

**Acceptance:**

- Feature status reports ready, pending, failed or skipped without copying secret/TAP values.
- Read-only reruns can inspect current status without reapplying CA/DNS/credential writes.
- Evaluate deployment-validation and candidate deployment-receipt with explicit adoption decision; feature permissions remain optional.

**Validation:**

- Use the offline commands in the registered validation workflow; record the exact commands, revision and results before implementation is complete.
- Run focused tests for changed behavior from tests/; fixtures do not prove live-service or endpoint behavior.

**Dependencies:**

- _none_

**Components:**

- deployment-validation
- deployment-receipt

**Sources:**

- README.md

**Evidence:**

- Completed local feature acceptance through independently reviewed PR &num;43 &lpar;https&colon;//github.com/nathanmcnulty/azd-myworkid/pull/43&rpar;, final reviewed head 54d8b572eef26f9a034cfa7c61f9c4a1661810a2, merged main 599c10c407b1b0058cd182284d1139a2f77a77a9 and equal tree aa812aa7a0fecdebde75b2983dfe7b4b21f5afbf. All six exact-head checks succeeded, including read-only setup status and .NET tests. Post-main CodeQL run 38116663961 succeeded; Test CI is PR-only, so test evidence is inherited from the identical reviewed tree rather than claimed as a main test run. Integration receipt SHA 433706012D6C7FEBA47FB1C831BC8608C2D0CEB24AC570B79DB7F7596AE9207F.
- Get-SetupStatus.ps1 reports fresh ready/pending/failed/skipped gates through the bounded MyWorkID.Status module. It binds selected account, tenant, subscription and exact application/resource identities; optional absent bindings and unavailable operator checks remain actionable pending. No CA/DNS/credential writes, provisioning replay, secret/TAP values or arbitrary provider error text are emitted. Optional status permissions are recorded with exact source hashes and explicit coverage gaps; metadata does not authorize grants.
- docs/setup-status.md evaluates immutable Reference 277584b33fcae7d47113718aad6428abdc4bc50f and explicitly defers deployment-validation 1.1.1 and candidate deployment-receipt 0.2.1 because this read-only status interface has no deployment operation accounting. No vendored runtime dependency or invented deployment receipt is introduced. Registered PowerShell 7.6.6 tests passed 39 cases, including wire JSON, no-write dispatch, secret sentinels, CLI selector shape and JWT identity refusal. Isolated .NET 8 restore/Release build and 22 unit plus 72 integration tests passed; the earlier reviewed client npm ci/build and Bicep evidence remains applicable to unchanged client/infra code. CLI repair independent review SHA 430A367874F3FFFF98B398536B053F4B3546B74E4D025431EC9979B2ED41A685.
- Additional bounded native proof passed actual cached CLI wrong-subscription refusal, one original cached-context call and zero downstream setup token/API/DNS/health dispatch under independently proven fail-closed guards, with before/after default context preserved. Native receipt SHA D1FF29523BCECE68536A2EB5BDEFC71019E0FD316CF635B433C9F41167C9D9D5 and independent review SHA 2FB2E2B5A88F584896357F62FFD533CF6E62F48D9FD3F3F6EDC82C5A5206BEB8. This is local feature acceptance and instrumented native refusal only&colon; no positive existing MyWorkID setup, effective permission, public DNS/TLS, delivery or user-journey acceptance is claimed. MWID-002 remains proposed for separate exact-target live qualification.

**Review and authorization note:**

Review MWID-003 against the current repository state. Its status or authorization class is not eligible for an actionable generated handoff. Do not claim or execute it without explicit selection, satisfied dependencies, and every required authorization. Never interpret this generated view as approval.
