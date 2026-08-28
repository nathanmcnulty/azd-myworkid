# Configuration

The default `releaseZip` mode is intended for administrators. It downloads:

`https://github.com/glueckkanja/MyWorkID/releases/<version>/download/binaries.zip`

Set `MYWORKID_RELEASE_VERSION` to pin a reviewed release. Set `MYWORKID_DEPLOY_MODE=sourceBuild` only for an intentional contributor build.

The template preserves MyWorkID settings for the App Service, authentication-context IDs, custom domains, Verified ID, Temporary Access Pass, branding, and reduced-permission modes. `azd` prompts for missing Bicep parameters and stores hook inputs in the selected local azd environment.

The three authentication contexts default to `c50`, `c51`, and `c52` for first-run validation. Replace them with the tenant's real context IDs before enabling those user journeys.

Available reduced-permission flags include:

- `skip_actions_requiring_global_admin`;
- `skip_creation_backend_access_groups`;
- `allow_credential_operations_for_privileged_users`.

Review what each flag changes before using it. A successful reduced-permission deployment may intentionally omit required product features.

## Custom domains

The automated flow supports subdomains using a CNAME record:

1. The first run prints the TXT verification value and CNAME target, then records `awaitingDns`.
2. After DNS propagation, rerun `azd up`; the hook validates both records before adding the binding.
3. When managed certificates are enabled, the hook waits for issuance and applies TLS.
4. The hook validates the public TLS handshake and `/api/general` health endpoint.
5. If propagation exceeds the retry window, it records `awaitingHttpsValidation` for a later safe rerun.

Apex/root domains remain a manual configuration path.
