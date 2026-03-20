# MyWorkID azd Template

This repository packages [MyWorkID](https://www.glueckkanja.com/en/security/my-work-id/) as an `azd`-first template. It keeps the existing MyWorkID application structure, but replaces the Terraform-led install flow with:

- `azd` + `Bicep` for Azure resource provisioning
- `azd` hooks plus Microsoft Graph REST for Entra application and permission setup
- two deployment modes:
  - `releaseZip` (default): deploy the published `binaries.zip` artifact without needing the .NET SDK or Node.js locally
  - `sourceBuild`: build and publish the checked-in source locally for contributor workflows

## Prerequisites

### Default `azd` flow

- Azure Developer CLI (`azd`) 1.23.7 or newer
- An Azure account with permission to create the target Azure resources
- Entra permissions equivalent to the original MyWorkID install flow

### Optional `sourceBuild` flow

- .NET SDK 8
- Node.js and npm

## Quick Start

1. Authenticate:

   ```powershell
   azd auth login
   ```

1. Create or select an environment:

   ```powershell
   azd env new
   ```

1. Optionally override deployment mode:

   ```powershell
   azd env set MYWORKID_DEPLOY_MODE sourceBuild
   azd env set MYWORKID_RELEASE_VERSION latest
   ```

1. Provision and deploy:

   ```powershell
   azd up
   ```

The template creates or updates the MyWorkID Azure resources, creates the required Entra application objects, and deploys the web app package to App Service.

## Configuration

The template preserves the important MyWorkID deployment settings from the original Terraform flow, including:

- App Service name and resource group
- auth context IDs
- custom domains
- Verified ID settings
- TAP settings
- branding URLs
- skip flags for reduced-permission environments

`azd` will prompt for missing Bicep parameters during provisioning. Values that the Entra hook workflow needs before provisioning are stored in the environment file automatically.

For first-run validation, the three auth context parameters default to `c50`, `c51`, and `c52`. Replace them with your real tenant auth context IDs before using the corresponding user journeys in production.

If you provide `custom_domains`, the template now uses a two-pass flow for CNAME-based custom domains:

- first run: the postprovision hook prints the TXT verification value and CNAME target, then sets `MYWORKID_CUSTOM_DOMAIN_CONFIGURATION_STATUS=awaitingDns`
- second run: after DNS has propagated, rerun `azd provision`; the hook validates the TXT and CNAME records, fails fast if they still do not match, then adds the hostname binding
- if `enable_app_service_managed_certificate=true` (default), the same rerun also requests an App Service managed certificate and completes the TLS binding when the certificate is ready
- App Service managed certificate issuance commonly takes up to 10 minutes, so the hook now waits longer and tells you when Azure is still propagating that step
- after the TLS binding is applied, the hook polls the public custom domain in 15-second intervals for up to about 5 minutes, validates the TLS handshake, and checks `https://<hostname>/api/general` for a healthy response before marking the domain as fully configured
- if Azure is still propagating the certificate or hostname binding after that retry window, the hook sets `MYWORKID_CUSTOM_DOMAIN_CONFIGURATION_STATUS=awaitingHttpsValidation` so a later `azd provision` can finish the validation pass

The automated binding flow currently assumes subdomains that use a CNAME record. Apex/root domains should still be completed manually.

## Deployment Modes

### `releaseZip`

This is the default mode. The packaging hook downloads:

`https://github.com/glueckkanja/MyWorkID/releases/<version>/download/binaries.zip`

with `latest` used when `MYWORKID_RELEASE_VERSION` is not set.

### `sourceBuild`

This mode builds:

- `src/MyWorkID.Client` with npm
- `src/MyWorkID.Server` with `dotnet publish`

and stages the combined output for `azd deploy`.

## Permissions Notes

The Entra automation uses Microsoft Graph through `azd auth token`. If the signed-in user lacks the required permissions, the hook scripts fail with a message that points to the missing operation. The following flags remain available:

- `skip_actions_requiring_global_admin`
- `skip_creation_backend_access_groups`
- `allow_credential_operations_for_privileged_users`

## Next Steps

After deployment, finish the tenant-specific setup described in [next-steps.md](next-steps.md), especially:

- Conditional Access and authentication context policies
- optional custom domain configuration
- optional Verified ID secret population

For the original product documentation, see the upstream wiki:

- https://github.com/glueckkanja/MyWorkID/wiki/Installation
- https://github.com/glueckkanja/MyWorkID/wiki/Conditional-Access
- https://github.com/glueckkanja/MyWorkID/wiki/Custom-Domain
- https://github.com/glueckkanja/MyWorkID/wiki/Verified-ID
