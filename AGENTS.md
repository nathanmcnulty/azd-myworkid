# Agent guidance

Read [docs/agent-assisted-deployment.md](docs/agent-assisted-deployment.md) before assisting with deployment.

- Never use or recommend device-code authentication.
- Separate read-only inspection from Azure, Entra, Conditional Access, DNS, credential, and cleanup writes.
- Verify account, tenant, subscription, exact target IDs, package version, and configuration before an authorized write.
- Do not print or persist tokens, credentials, TAP values, Verified ID secrets, or real azd environment contents.
- Stop at authentication, consent, permission, tenant, or ownership mismatches.
