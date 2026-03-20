targetScope = 'subscription'

@metadata({
  azd: {
    type: 'resourceGroup'
  }
})
param resource_group_name string = 'rg-MyWorkID'

@metadata({
  azd: {
    type: 'location'
    default: 'westeurope'
  }
})
param resource_location string = 'westeurope'

param tenant_id string = subscription().tenantId
param subscription_id string = subscription().subscriptionId

@description('Globally unique App Service name for the MyWorkID application.')
param api_name string

param backed_appreg_name string = 'ar-MyWorkID-backend'
param frontend_appreg_name string = 'ar-MyWorkID-frontend'

@description('AuthContext Id configured that is challenged for the dismissUser action. Defaults to c50 for first-run validation.')
param dismiss_user_risk_auth_context_id string = 'c50'

@description('AuthContext Id configured that is challenged for the generateTAP action. Defaults to c51 for first-run validation.')
param generate_tap_auth_context_id string = 'c51'

@description('AuthContext Id configured that is challenged for the resetPassword action. Defaults to c52 for first-run validation.')
param reset_password_auth_context_id string = 'c52'

param skip_actions_requiring_global_admin bool = false
param skip_creation_backend_access_groups bool = false
param allow_credential_operations_for_privileged_users bool = false
param custom_domains array = []
param custom_domains_csv string = ''
param enable_app_service_managed_certificate bool = true
param enable_app_service_managed_certificate_string string = ''
param backend_client_id string
param frontend_client_id string
param verified_id_jwt_signing_key_secret_name string = 'VerifiedId-JwtSigningKey'
param verified_id_decentralized_identifier_secret_name string = 'VerifiedId-DecentralizedIdentifier'
param verified_id_verify_security_attribute_set string = 'MyWorkID'
param verified_id_verify_security_attribute string = 'lastVerifiedFaceCheck'

@minValue(50)
@maxValue(100)
param verified_id_face_match_confidence_threshold int = 70

param custom_css_url string = ''
param app_title string = ''
param favicon_url string = ''

@minValue(0)
param tap_lifetime_in_minutes int = 0

param tap_is_usable_once string = ''

param backend_access_group_names object = {
  create_tap: 'sec - MyWorkID - Create TAP'
  dismiss_user_risk: 'sec - MyWorkID - Dismiss User Risk'
  password_reset: 'sec - MyWorkID - Password Reset'
  validate_identity: 'sec - MyWorkID - Validate Identity'
}

param is_dev bool = false
param dev_redirect_url array = []

resource mainResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resource_group_name
  location: resource_location
}

var custom_domain_candidates = empty(custom_domains_csv) ? custom_domains : split(custom_domains_csv, ',')
var effective_custom_domains = [for domain in custom_domain_candidates: trim(string(domain))]
var effective_enable_app_service_managed_certificate = empty(enable_app_service_managed_certificate_string)
  ? enable_app_service_managed_certificate
  : toLower(enable_app_service_managed_certificate_string) == 'true'

module myworkid './modules/myworkid.bicep' = {
  name: 'myworkid-${uniqueString(subscription().subscriptionId, resource_group_name, api_name)}'
  scope: mainResourceGroup
  params: {
    location: resource_location
    tenant_id: tenant_id
    api_name: api_name
    backend_client_id: backend_client_id
    frontend_client_id: frontend_client_id
    dismiss_user_risk_auth_context_id: dismiss_user_risk_auth_context_id
    generate_tap_auth_context_id: generate_tap_auth_context_id
    reset_password_auth_context_id: reset_password_auth_context_id
    custom_domains: effective_custom_domains
    verified_id_jwt_signing_key_secret_name: verified_id_jwt_signing_key_secret_name
    verified_id_decentralized_identifier_secret_name: verified_id_decentralized_identifier_secret_name
    verified_id_verify_security_attribute_set: verified_id_verify_security_attribute_set
    verified_id_verify_security_attribute: verified_id_verify_security_attribute
    verified_id_face_match_confidence_threshold: verified_id_face_match_confidence_threshold
    custom_css_url: custom_css_url
    app_title: app_title
    favicon_url: favicon_url
    tap_lifetime_in_minutes: tap_lifetime_in_minutes
    tap_is_usable_once: tap_is_usable_once
  }
}

output AZURE_RESOURCE_GROUP string = resource_group_name
output AZURE_LOCATION string = resource_location
output AZURE_TENANT_ID string = tenant_id
output AZURE_SUBSCRIPTION_ID string = subscription_id
output SERVICE_WEB_NAME string = myworkid.outputs.service_web_name
output SERVICE_WEB_ENDPOINT_URL string = myworkid.outputs.service_web_endpoint_url
output MYWORKID_APP_SERVICE_DEFAULT_HOSTNAME string = myworkid.outputs.app_service_default_hostname
output MYWORKID_APP_SERVICE_CUSTOM_DOMAIN_VERIFICATION_ID string = myworkid.outputs.app_service_custom_domain_verification_id
output MYWORKID_KEY_VAULT_NAME string = myworkid.outputs.key_vault_name
output MYWORKID_MANAGED_IDENTITY_PRINCIPAL_ID string = myworkid.outputs.managed_identity_principal_id
output MYWORKID_BACKEND_CLIENT_ID string = backend_client_id
output MYWORKID_FRONTEND_CLIENT_ID string = frontend_client_id
output MYWORKID_BACKED_APPREG_NAME string = backed_appreg_name
output MYWORKID_FRONTEND_APPREG_NAME string = frontend_appreg_name
output MYWORKID_CUSTOM_DOMAINS string = join(effective_custom_domains, ',')
output MYWORKID_ENABLE_APP_SERVICE_MANAGED_CERTIFICATE string = effective_enable_app_service_managed_certificate ? 'true' : 'false'
output MYWORKID_IS_DEV string = is_dev ? 'true' : 'false'
output MYWORKID_DEV_REDIRECT_URLS string = join(dev_redirect_url, ',')
output MYWORKID_SKIP_ACTIONS_REQUIRING_GLOBAL_ADMIN string = skip_actions_requiring_global_admin ? 'true' : 'false'
output MYWORKID_SKIP_CREATION_BACKEND_ACCESS_GROUPS string = skip_creation_backend_access_groups ? 'true' : 'false'
output MYWORKID_ALLOW_CREDENTIAL_OPERATIONS_FOR_PRIVILEGED_USERS string = allow_credential_operations_for_privileged_users ? 'true' : 'false'
output MYWORKID_CREATE_TAP_GROUP_NAME string = string(backend_access_group_names.create_tap)
output MYWORKID_DISMISS_USER_RISK_GROUP_NAME string = string(backend_access_group_names.dismiss_user_risk)
output MYWORKID_PASSWORD_RESET_GROUP_NAME string = string(backend_access_group_names.password_reset)
output MYWORKID_VALIDATE_IDENTITY_GROUP_NAME string = string(backend_access_group_names.validate_identity)
