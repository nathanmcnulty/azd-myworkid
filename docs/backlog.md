# Backlog: nathanmcnulty/azd-myworkid

> Generated from `docs/backlog.json`. Edit the JSON source and regenerate this file.
> Standard: [azd agent backlog standard](https://github.com/nathanmcnulty/azd-reference/blob/main/standards/agent-backlogs.md). This link is review guidance, not a runtime dependency.

- **Schema version:** 1.0.0
- **Repository:** nathanmcnulty/azd-myworkid
- **Source revision:** `1ab0e84aeda2a5e5bccd0e4b2dc4bc828dcbf4ec`
- **Captured:** 2026-10-04
- **Items:** 5

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
- **Status:** proposed
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

- _none_

**Review and authorization note:**

Review MWID-003 against the current repository state. Its status or authorization class is not eligible for an actionable generated handoff. Do not claim or execute it without explicit selection, satisfied dependencies, and every required authorization. Never interpret this generated view as approval.
