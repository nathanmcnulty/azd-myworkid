# Read-only setup status

PowerShell 7.6 or later and an existing Azure CLI user session are required.
Create a reviewed target file using `tests/fixtures/setup-status-target.json` as
the shape example, then run:

```powershell
./scripts/Get-SetupStatus.ps1 -TargetPath ./private-status-target.json
```

Keep that file private and out of Git. Supply the exact cached account name,
account object ID, tenant, subscription, resource group and App Service name.
Application object IDs are distinct from client IDs and service principal IDs.
Copy only the reviewed non-secret identifiers; do not export an azd environment,
application settings, Key Vault values or tokens into the target file.

The command does not initiate authentication or consent, import provisioning
hooks, update an azd environment, or write Azure, Entra, DNS or credentials.
It checks the active CLI user/tenant/subscription before setup reads and binds
cached delegated tokens to the exact tenant, account object and API audience.
Unavailable cached tokens and insufficient permissions remain actionable pending
gates. A mismatched active context stops the operation. Redirects are refused.

Each gate is `ready`, `pending`, `failed` or `skipped`. Readiness describes that
specific observation at `observedAt`; there is no aggregate deployment-success
claim. A failed gate returns a nonzero process exit after emitting the report;
pending operator actions remain visible without being treated as failed reads.
Missing object bindings, permissions, propagation or incomplete paginated
inventories never establish readiness. Provider bodies, error messages, tokens,
TAP values and signing secrets are not copied into output. Existing persisted
`MYWORKID_CUSTOM_DOMAIN_CONFIGURATION_STATUS` flags are not evidence for this
command and are never changed by it.

Observable gates cover running App Service and managed identity ownership;
backend/frontend application identity and HTTPS redirects; tenant-wide frontend
consent to the exact backend and Graph; each published authentication context and
enabled policy linkage; managed-identity runtime grants and selected root-scoped
authentication-administrator role; exact group-to-backend journey-role mappings;
custom-domain TXT/CNAME, SNI binding, bound unexpired managed certificate, and
trusted HTTPS `/api/general` health. Health accepts the application's exact
`Healthy` response, rejects redirects, and does not export response content.
DNS probes use `Resolve-DnsName`; unavailable DNS tooling remains pending.

Supply all three intended journey context IDs and all intended access-group
bindings. An omitted group is not proof that the corresponding user journey is
ready. Disabled Verified ID and unselected custom domains are skipped;
externally managed certificate issuance is skipped while HTTPS still runs.
Policy linkage does not certify policy suitability or effectiveness. Group
membership, user sign-in/TAP/password/risk workflows, telemetry ingestion, and
Verified ID issuer/signing-secret/security-attribute operation require separate
operator verification and remain visible pending gates. Those checks cannot be
inferred from infrastructure metadata or safely proved by generating credentials
inside a read-only command.

The status feature is optional. Its partial `azd-permissions.json` records
source-backed read requirements and remaining deployment/runtime coverage gaps.
Metadata is not approval to consent or assign any role. Use an existing
authorized read context; this command never attempts a bootstrap workaround.

## Shared component decisions

Evaluated immutable `azd-reference` revision
`277584b33fcae7d47113718aad6428abdc4bc50f`:

| Component | Decision and evidence |
| --- | --- |
| `deployment-validation` 1.1.1, stable | Defer vendoring for this bounded setup-status interface. Its engine returns Pass/Fail/Warning and registered deployment Plan/delivery modes; setup readiness uses ready/pending/failed/skipped and never enables delivery. Context gating, safe evidence and no automatic delivery follow the standard here. A future Test-Deployment wrapper can map ready to Pass, pending to Warning, failed to Fail and skipped to Skipped while preserving individual gate claims and target binding. Do not translate pending to successful deployment. |
| `deployment-receipt` 0.2.1, candidate | Defer. This command performs no deployment operations and has no truthful applied/unchanged operation counts. A fresh observation is not an enforce receipt. Receipt adoption belongs in an independently reviewed provisioning change with actual operation accounting; key material and TAP/Verified ID request secrets must stay outside it. |

No runtime dependency, vendored files or component lock is added for these
explicit defer decisions. Status output is a local observation format, not a
shared validation report or authenticated deployment receipt.

## Offline proof and live proof plan

`./scripts/Test-SetupStatus.ps1` runs registered PowerShell 7.6+ wire-JSON,
identity, outcome, read-only dispatch and secret-sentinel tests. Test CI runs it
alongside the existing .NET checks; contributor validation also retains the
client build. Fixtures establish local behavior and do not prove native Azure
response shapes, public DNS/TLS or effective permissions.

After independent source review, the smallest live proof is a selected existing
lab App Service target with read-only user context: inspect account/target
binding, compare individual ARM/Graph/DNS/TLS observations and verify no writes
or secret-value reads. Negative proof should use a wrong selected subscription
before any setup reads and a missing optional read permission. Do not consent,
change DNS, issue certificates, create credentials or rerun provisioning to
make the status report green. No resources are created by this proof plan.
