# Architecture

The template replaces the upstream Terraform-led installation path with Azure Developer CLI orchestration:

- `azd` and Bicep provision the Azure resources;
- lifecycle hooks use Microsoft Graph REST to prepare Entra applications and permissions;
- `releaseZip` downloads a published upstream `binaries.zip` package and deploys it to App Service;
- `sourceBuild` builds the checked-in client and server source before deployment.

The Azure, Entra, application-package, DNS, and Conditional Access boundaries remain separate. A successful Azure deployment does not prove that tenant-specific authentication contexts, Conditional Access, Verified ID secrets, DNS, or public TLS are complete.

The Entra hook uses the access available to the signed-in administrator and fails when the required operation is not authorized. It does not silently broaden its authority.
