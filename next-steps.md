# MyWorkID Next Steps

The `azd` template provisions Azure resources and automates the tenant object creation that can be handled safely through Microsoft Graph. The remaining setup is still tenant-specific and should be reviewed intentionally.

## Finish Entra policy setup

- Create or confirm the authentication contexts referenced by:
  - `dismiss_user_risk_auth_context_id`
  - `generate_tap_auth_context_id`
  - `reset_password_auth_context_id`
- Apply the expected Conditional Access policies for the MyWorkID user journeys.
- If the postprovision hook warns that directory role assignment could not be completed automatically, assign the App Service managed identity to `Authentication Administrator` or `Privileged Authentication Administrator` manually, depending on your chosen setting.

## Optional custom domain

- The automated flow currently assumes subdomains that use a CNAME record. Apex/root domains should still be completed manually.
- On the first `azd provision`, the postprovision hook prints the required DNS records and sets `MYWORKID_CUSTOM_DOMAIN_CONFIGURATION_STATUS=awaitingDns`.
- Create the TXT record `asuid.<hostname>` with the value from `MYWORKID_APP_SERVICE_CUSTOM_DOMAIN_VERIFICATION_ID`.
- Create a CNAME from the custom hostname to `MYWORKID_APP_SERVICE_DEFAULT_HOSTNAME`.
- Wait for both records to propagate, then rerun `azd provision`.
- On the follow-up run, the hook validates the TXT and CNAME records before it tries to add the App Service hostname binding. If the DNS records still do not match, the run fails fast with the expected and current values.
- If `enable_app_service_managed_certificate=true`, the same follow-up run also requests an App Service managed certificate and completes the SNI binding when the certificate thumbprint becomes available.
- App Service managed certificate issuance commonly takes up to 10 minutes. The hook now tells you when it is waiting on that Azure-side step and leaves the environment in `awaitingManagedCertificate` if the certificate is still being issued.
- After the SNI binding is applied, the hook polls the public hostname every 15 seconds for up to about 5 minutes, validates the TLS certificate handshake, and checks `https://<hostname>/api/general` for a healthy response.
- If that final validation window expires before the hostname is fully live, the environment is marked with `MYWORKID_CUSTOM_DOMAIN_CONFIGURATION_STATUS=awaitingHttpsValidation`. Rerun `azd provision` after a few minutes to finish the validation pass.
- If you use a custom domain, confirm the frontend redirect URIs include the final HTTPS origin.

## Optional Verified ID setup

- Populate the Key Vault secrets referenced by:
  - `VerifiedId-JwtSigningKey`
  - `VerifiedId-DecentralizedIdentifier`
- Verify that the tenant has the required Verified ID issuer configuration.
- Confirm the configured security attribute set and attribute names match your tenant design.

## Validation

- Sign in to the frontend and confirm the app can acquire tokens for the backend.
- Verify TAP generation, password reset, and dismiss user risk flows with the intended access groups.
- Verify Application Insights telemetry arrives in the created workspace.
