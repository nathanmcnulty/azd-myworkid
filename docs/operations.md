# Operations

## Verification

After deployment, verify the Azure resources, App Service health, exact Entra application objects and permissions, authentication-context IDs, and every tenant-specific item in [next-steps.md](../next-steps.md).

For a custom domain, verify the published TXT and CNAME records, App Service hostname binding, certificate state, public TLS handshake, and `https://<hostname>/api/general`. DNS and certificate propagation can require a later `azd up`; the saved status makes that rerun resumable.

## Troubleshooting

- If an Entra operation is unauthorized, review the signed-in account and required administrator role. Do not bypass the failed operation with a weaker authentication flow.
- If DNS validation fails, compare the exact printed TXT value and CNAME target with public DNS.
- If certificate issuance is still propagating, retain the environment and rerun after Azure reports the binding ready.
- If application health fails, confirm the package version, App Service configuration, and tenant next steps before repeating provisioning.

## Cleanup

`azd down --purge` removes the Azure deployment. It does not automatically delete tenant application objects, Conditional Access policies, externally managed DNS, or secrets supplied outside the deployment. Inventory those objects by exact ID and remove them only with explicit administrator approval.
