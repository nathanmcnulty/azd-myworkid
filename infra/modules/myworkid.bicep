param location string
param tenant_id string
param api_name string
param backend_client_id string
param frontend_client_id string
param dismiss_user_risk_auth_context_id string
param generate_tap_auth_context_id string
param reset_password_auth_context_id string
param custom_domains array
param verified_id_jwt_signing_key_secret_name string
param verified_id_decentralized_identifier_secret_name string
param verified_id_verify_security_attribute_set string
param verified_id_verify_security_attribute string
param verified_id_face_match_confidence_threshold int
param custom_css_url string
param app_title string
param favicon_url string
param tap_lifetime_in_minutes int
param tap_is_usable_once string

var is_custom_domain_configured = length(custom_domains) > 0
var verified_id_backend_url = is_custom_domain_configured
  ? 'https://${custom_domains[0]}'
  : 'https://${api_name}.azurewebsites.net'
var key_vault_name = length('kv-${api_name}') > 24 ? substring('kv-${api_name}', 0, 24) : 'kv-${api_name}'
var base_tags = {
  'azd-service-name': 'web'
}
var web_app_settings = union({
  AppFunctions__DismissUserRisk: dismiss_user_risk_auth_context_id
  AppFunctions__GenerateTap: generate_tap_auth_context_id
  AppFunctions__ResetPassword: reset_password_auth_context_id
  AzureAd__ClientId: backend_client_id
  AzureAd__TenantId: tenant_id
  AzureAd__Instance: 'https://login.microsoftonline.com/'
  Frontend__FrontendClientId: frontend_client_id
  Frontend__BackendClientId: backend_client_id
  Frontend__TenantId: tenant_id
  Frontend__CustomCssUrl: custom_css_url
  Frontend__AppTitle: app_title
  Frontend__FaviconUrl: favicon_url
  WEBSITE_RUN_FROM_PACKAGE: '1'
  SCM_DO_BUILD_DURING_DEPLOYMENT: 'false'
  APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
  ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
  XDT_MicrosoftApplicationInsights_Mode: 'recommended'
  VerifiedId__JwtSigningKey: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=${verified_id_jwt_signing_key_secret_name})'
  VerifiedId__DecentralizedIdentifier: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=${verified_id_decentralized_identifier_secret_name})'
  VerifiedId__TargetSecurityAttributeSet: verified_id_verify_security_attribute_set
  VerifiedId__TargetSecurityAttribute: verified_id_verify_security_attribute
  VerifiedId__BackendUrl: verified_id_backend_url
  VerifiedId__CreatePresentationRequestUri: 'https://verifiedid.did.msidentity.com/v1.0/verifiableCredentials/createPresentationRequest'
  VerifiedId__FaceMatchConfidenceThreshold: string(verified_id_face_match_confidence_threshold)
}, tap_lifetime_in_minutes > 0 ? {
  Tap__LifetimeInMinutes: string(tap_lifetime_in_minutes)
} : {}, empty(tap_is_usable_once) ? {} : {
  Tap__IsUsableOnce: tap_is_usable_once
})

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'asp-${api_name}'
  location: location
  kind: 'linux'
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  properties: {
    reserved: true
  }
  tags: base_tags
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'wsp-${api_name}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
  tags: base_tags
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'ai-${api_name}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
  tags: base_tags
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: key_vault_name
  location: location
  properties: {
    enableRbacAuthorization: true
    enabledForDeployment: false
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: false
    tenantId: tenant_id
    softDeleteRetentionInDays: 7
    enablePurgeProtection: true
    sku: {
      family: 'A'
      name: 'standard'
    }
    publicNetworkAccess: 'Enabled'
  }
  tags: base_tags
}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: api_name
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      alwaysOn: true
      minTlsVersion: '1.2'
      linuxFxVersion: 'DOTNETCORE|8.0'
      ftpsState: 'Disabled'
      http20Enabled: true
    }
  }
  tags: base_tags
}

resource webAppAppSettings 'Microsoft.Web/sites/config@2023-12-01' = {
  name: '${webApp.name}/appsettings'
  properties: web_app_settings
}

resource keyVaultSecretsUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, webApp.name, 'KeyVaultSecretsUser')
  scope: keyVault
  properties: {
    principalId: webApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
  }
}

output service_web_name string = webApp.name
output service_web_endpoint_url string = 'https://${webApp.properties.defaultHostName}'
output app_service_default_hostname string = webApp.properties.defaultHostName
output app_service_custom_domain_verification_id string = webApp.properties.customDomainVerificationId
output key_vault_name string = keyVault.name
output managed_identity_principal_id string = webApp.identity.principalId
