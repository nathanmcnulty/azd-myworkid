Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:GraphBaseUri = 'https://graph.microsoft.com/v1.0'
$script:ArmBaseUri = 'https://management.azure.com'
$script:GraphScope = 'https://graph.microsoft.com/.default'
$script:ArmScope = 'https://management.azure.com/.default'
$script:MicrosoftGraphAppId = '00000003-0000-0000-c000-000000000000'
$script:VerifiableCredentialsAppId = '3db474b9-6a0c-4840-96ac-1fceb342124f'
$script:VerifiableCredentialsCreateAllRoleId = '949ebb93-18f8-41b4-b677-c2bfea940027'
$script:BackendAccessScopeId = '7e119516-7dd5-4cc0-a906-5f1a9cfd5801'
$script:CreateTapRoleId = '16f5de80-8ee7-46e3-8bfe-7de7af6164ed'
$script:DismissUserRiskRoleId = '9262ab98-6c08-4e32-bae3-4c12d4ce2463'
$script:PasswordResetRoleId = '13c4693c-84f1-43b4-85a2-5e51d41753ed'
$script:ValidateIdentityRoleId = 'eeacf7de-5c05-4e21-a2be-a4d8e3435237'
$script:TokenCache = @{}
$script:ProviderNamespaces = @(
    'Microsoft.ManagedIdentity',
    'Microsoft.KeyVault',
    'Microsoft.Web',
    'Microsoft.Insights',
    'Microsoft.OperationalInsights'
)

function Import-AzdEnvironment {
    $lines = azd env get-values
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $parts = $line -split '=', 2
        if ($parts.Length -ne 2) {
            continue
        }

        $name = $parts[0].Trim()
        $value = $parts[1].Trim()

        if ($value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"')) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        Set-Item -Path "Env:$name" -Value $value
    }
}

function Get-OptionalEnvValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [string]$Default = ''
    )

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }

    return $value
}

function Get-RequiredEnvValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $value = Get-OptionalEnvValue -Name $Name
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Required environment value '$Name' is missing. Set it with 'azd env set $Name <value>' or rerun the hook after azd initializes the environment."
    }

    return $value
}

function Set-AzdEnvironmentValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    $current = Get-OptionalEnvValue -Name $Name
    if ($current -eq $Value) {
        return
    }

    azd env set $Name $Value | Out-Null
    Set-Item -Path "Env:$Name" -Value $Value
}

function ConvertTo-Boolean {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return [string]::Equals($Value, 'true', [System.StringComparison]::OrdinalIgnoreCase)
}

function Split-CommaList {
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @()
    }

    return @(
        $Value.Split(',', [System.StringSplitOptions]::RemoveEmptyEntries) |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function Ensure-TrailingSlash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri
    )

    if ($Uri.EndsWith('/')) {
        return $Uri
    }

    return "$Uri/"
}

function New-SafeMailNickname {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    $nickname = ($DisplayName -replace '[^A-Za-z0-9-]', '').ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($nickname)) {
        $nickname = 'myworkid'
    }

    if ($nickname.Length -gt 64) {
        $nickname = $nickname.Substring(0, 64)
    }

    return $nickname
}

function New-RandomSuffix {
    param(
        [int]$Length = 8
    )

    $chars = 'abcdefghijklmnopqrstuvwxyz0123456789'.ToCharArray()
    $buffer = New-Object char[] $Length
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] $Length
    $rng.GetBytes($bytes)
    for ($i = 0; $i -lt $Length; $i++) {
        $buffer[$i] = $chars[$bytes[$i] % $chars.Length]
    }

    return -join $buffer
}

function Ensure-TemplateDefaults {
    $envName = Get-OptionalEnvValue -Name 'AZURE_ENV_NAME' -Default 'dev'
    $safeEnvName = ($envName.ToLowerInvariant() -replace '[^a-z0-9-]', '')
    if ([string]::IsNullOrWhiteSpace($safeEnvName)) {
        $safeEnvName = 'dev'
    }

    if ([string]::IsNullOrWhiteSpace((Get-OptionalEnvValue -Name 'MYWORKID_API_NAME'))) {
        $generated = "myworkid-$safeEnvName-$(New-RandomSuffix -Length 6)"
        Set-AzdEnvironmentValue -Name 'MYWORKID_API_NAME' -Value $generated
    }

    if ([string]::IsNullOrWhiteSpace((Get-OptionalEnvValue -Name 'MYWORKID_BACKED_APPREG_NAME'))) {
        Set-AzdEnvironmentValue -Name 'MYWORKID_BACKED_APPREG_NAME' -Value 'ar-MyWorkID-backend'
    }

    if ([string]::IsNullOrWhiteSpace((Get-OptionalEnvValue -Name 'MYWORKID_FRONTEND_APPREG_NAME'))) {
        Set-AzdEnvironmentValue -Name 'MYWORKID_FRONTEND_APPREG_NAME' -Value 'ar-MyWorkID-frontend'
    }

    if ([string]::IsNullOrWhiteSpace((Get-OptionalEnvValue -Name 'MYWORKID_DEPLOY_MODE'))) {
        Set-AzdEnvironmentValue -Name 'MYWORKID_DEPLOY_MODE' -Value 'releaseZip'
    }

    if ([string]::IsNullOrWhiteSpace((Get-OptionalEnvValue -Name 'MYWORKID_RELEASE_VERSION'))) {
        Set-AzdEnvironmentValue -Name 'MYWORKID_RELEASE_VERSION' -Value 'latest'
    }

    if ([string]::IsNullOrWhiteSpace((Get-OptionalEnvValue -Name 'MYWORKID_ENABLE_APP_SERVICE_MANAGED_CERTIFICATE'))) {
        Set-AzdEnvironmentValue -Name 'MYWORKID_ENABLE_APP_SERVICE_MANAGED_CERTIFICATE' -Value 'true'
    }
}

function Get-AzdAccessToken {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Scope
    )

    if (-not $script:TokenCache.ContainsKey($Scope)) {
        $result = azd auth token --output json --scope $Scope | ConvertFrom-Json
        $script:TokenCache[$Scope] = $result.token
    }

    return $script:TokenCache[$Scope]
}

function Get-ErrorMessage {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $message = $ErrorRecord.Exception.Message
    $response = $ErrorRecord.Exception.Response
    if ($null -ne $response) {
        try {
            $stream = $response.GetResponseStream()
            if ($null -ne $stream) {
                $reader = New-Object System.IO.StreamReader($stream)
                $body = $reader.ReadToEnd()
                if (-not [string]::IsNullOrWhiteSpace($body)) {
                    $message = "$message`n$body"
                }
            }
        }
        catch {
        }
    }

    return $message
}

function Invoke-JsonApiRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [string]$Scope,

        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
        [string]$Method = 'GET',

        [object]$Body = $null,

        [switch]$IgnoreNotFound
    )

    $headers = @{
        Authorization = "Bearer $(Get-AzdAccessToken -Scope $Scope)"
    }

    $invokeParams = @{
        Uri = $Uri
        Method = $Method
        Headers = $headers
    }

    if ($null -ne $Body) {
        $invokeParams['ContentType'] = 'application/json'
        $invokeParams['Body'] = ($Body | ConvertTo-Json -Depth 50 -Compress)
    }

    try {
        return Invoke-RestMethod @invokeParams
    }
    catch {
        $response = $_.Exception.Response
        if ($IgnoreNotFound -and $null -ne $response -and [int]$response.StatusCode -eq 404) {
            return $null
        }

        throw (Get-ErrorMessage -ErrorRecord $_)
    }
}

function Invoke-GraphRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
        [string]$Method = 'GET',

        [object]$Body = $null,

        [switch]$IgnoreNotFound
    )

    return Invoke-JsonApiRequest -Uri "$($script:GraphBaseUri)$Path" -Scope $script:GraphScope -Method $Method -Body $Body -IgnoreNotFound:$IgnoreNotFound
}

function Invoke-ArmRequest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
        [string]$Method = 'GET',

        [object]$Body = $null,

        [switch]$IgnoreNotFound
    )

    return Invoke-JsonApiRequest -Uri "$($script:ArmBaseUri)$Path" -Scope $script:ArmScope -Method $Method -Body $Body -IgnoreNotFound:$IgnoreNotFound
}

function New-FilterQuery {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Filter
    )

    return [System.Uri]::EscapeDataString($Filter)
}

function Get-GraphCollection {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $result = Invoke-GraphRequest -Path $Path
    if ($null -eq $result) {
        return @()
    }

    if ($null -ne $result.value) {
        return @($result.value)
    }

    return @($result)
}

function Get-DirectoryObjectIds {
    param(
        [AllowNull()]
        [object[]]$Items
    )

    if ($null -eq $Items) {
        return @()
    }

    return @(
        $Items |
        ForEach-Object {
            if ($null -ne $_ -and $null -ne $_.PSObject.Properties['id']) {
                $_.id
            }
        } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function Get-CurrentUserId {
    $me = Invoke-GraphRequest -Path "/me?`$select=id"
    return $me.id
}

function Get-ApplicationByDisplayName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    $filter = New-FilterQuery -Filter "displayName eq '$DisplayName'"
    $apps = Get-GraphCollection -Path "/applications?`$filter=$filter&`$select=id,appId,displayName,identifierUris,spa,requiredResourceAccess"
    return $apps | Select-Object -First 1
}

function Get-ServicePrincipalByAppId {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppId
    )

    $filter = New-FilterQuery -Filter "appId eq '$AppId'"
    $servicePrincipals = Get-GraphCollection -Path "/servicePrincipals?`$filter=$filter&`$select=id,appId,appRoles,oauth2PermissionScopes,displayName"
    return $servicePrincipals | Select-Object -First 1
}

function Get-ApplicationById {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    return Invoke-GraphRequest -Path "/applications/${Id}?`$select=id,appId,displayName,identifierUris,spa,requiredResourceAccess"
}

function Get-ServicePrincipalById {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id
    )

    return Invoke-GraphRequest -Path "/servicePrincipals/${Id}?`$select=id,appId,appRoles,oauth2PermissionScopes,displayName"
}

function Get-GroupByDisplayName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    $filter = New-FilterQuery -Filter "displayName eq '$DisplayName'"
    $groups = Get-GraphCollection -Path "/groups?`$filter=$filter&`$select=id,displayName"
    return $groups | Select-Object -First 1
}

function Ensure-ApplicationOwner {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApplicationId,

        [Parameter(Mandatory = $true)]
        [string]$OwnerObjectId
    )

    $owners = Get-GraphCollection -Path "/applications/$ApplicationId/owners?`$select=id"
    $ownerIds = Get-DirectoryObjectIds -Items $owners
    if ($ownerIds -contains $OwnerObjectId) {
        return
    }

    Invoke-GraphRequest -Path "/applications/$ApplicationId/owners/`$ref" -Method POST -Body @{
        '@odata.id' = "$($script:GraphBaseUri)/directoryObjects/$OwnerObjectId"
    } | Out-Null
}

function Ensure-ServicePrincipalOwner {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServicePrincipalId,

        [Parameter(Mandatory = $true)]
        [string]$OwnerObjectId
    )

    $owners = Get-GraphCollection -Path "/servicePrincipals/$ServicePrincipalId/owners?`$select=id"
    $ownerIds = Get-DirectoryObjectIds -Items $owners
    if ($ownerIds -contains $OwnerObjectId) {
        return
    }

    Invoke-GraphRequest -Path "/servicePrincipals/$ServicePrincipalId/owners/`$ref" -Method POST -Body @{
        '@odata.id' = "$($script:GraphBaseUri)/directoryObjects/$OwnerObjectId"
    } | Out-Null
}

function Get-BackendApplicationDefinition {
    return @{
        signInAudience = 'AzureADMyOrg'
        api = @{
            requestedAccessTokenVersion = 2
            oauth2PermissionScopes = @(
                @{
                    id = $script:BackendAccessScopeId
                    adminConsentDescription = 'Access To MyWorkID backend'
                    adminConsentDisplayName = 'Access'
                    isEnabled = $true
                    type = 'Admin'
                    value = 'Access'
                }
            )
        }
        appRoles = @(
            @{
                allowedMemberTypes = @('User')
                description = 'Allows user to Create a temporary access token'
                displayName = 'MyWorkID.CreateTAP'
                id = $script:CreateTapRoleId
                isEnabled = $true
                value = 'MyWorkID.CreateTAP'
            },
            @{
                allowedMemberTypes = @('User')
                description = 'Allows user to Dismiss its User Risk'
                displayName = 'MyWorkID.DismissUserRisk'
                id = $script:DismissUserRiskRoleId
                isEnabled = $true
                value = 'MyWorkID.DismissUserRisk'
            },
            @{
                allowedMemberTypes = @('User')
                description = 'Allows user to Reset its password'
                displayName = 'MyWorkID.PasswordReset'
                id = $script:PasswordResetRoleId
                isEnabled = $true
                value = 'MyWorkID.PasswordReset'
            },
            @{
                allowedMemberTypes = @('User')
                description = 'Allows user to Validate its Identity by VerifiedId'
                displayName = 'MyWorkID.ValidateIdentity'
                id = $script:ValidateIdentityRoleId
                isEnabled = $true
                value = 'MyWorkID.ValidateIdentity'
            }
        )
    }
}

function Ensure-BackendApplication {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter(Mandatory = $true)]
        [string]$OwnerObjectId
    )

    $existing = Get-ApplicationByDisplayName -DisplayName $DisplayName
    $payload = Get-BackendApplicationDefinition
    $payload['displayName'] = $DisplayName
    $created = $false

    if ($null -eq $existing) {
        $createdApp = Invoke-GraphRequest -Path '/applications' -Method POST -Body $payload
        if ($null -ne $createdApp -and $null -ne $createdApp.id) {
            $app = Get-ApplicationById -Id $createdApp.id
        }
        else {
            $app = Get-ApplicationByDisplayName -DisplayName $DisplayName
        }
        $created = $true
    }
    else {
        Invoke-GraphRequest -Path "/applications/$($existing.id)" -Method PATCH -Body $payload | Out-Null
        $app = Get-ApplicationById -Id $existing.id
    }

    if ($null -eq $app -or $null -eq $app.PSObject.Properties['id']) {
        $app = Get-ApplicationByDisplayName -DisplayName $DisplayName
    }

    if ($null -eq $app -or $null -eq $app.PSObject.Properties['id']) {
        throw "Unable to resolve backend application '$DisplayName' after create/update."
    }

    Ensure-ApplicationOwner -ApplicationId $app.id -OwnerObjectId $OwnerObjectId

    $expectedIdentifierUri = "api://$($app.appId)"
    if ($null -eq $app.identifierUris -or $app.identifierUris -notcontains $expectedIdentifierUri) {
        Invoke-GraphRequest -Path "/applications/$($app.id)" -Method PATCH -Body @{
            identifierUris = @($expectedIdentifierUri)
        } | Out-Null
    }

    return [pscustomobject]@{
        Id = $app.id
        AppId = $app.appId
        Created = $created
    }
}

function Ensure-FrontendApplication {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter(Mandatory = $true)]
        [string]$OwnerObjectId,

        [Parameter(Mandatory = $true)]
        [string]$BackendAppId,

        [Parameter(Mandatory = $true)]
        [string]$GraphUserReadScopeId,

        [AllowNull()]
        [string[]]$RedirectUris
    )

    $normalizedRedirectUris = @(($RedirectUris ?? @()) | ForEach-Object { Ensure-TrailingSlash -Uri $_ } | Sort-Object -Unique)
    $payload = @{
        displayName = $DisplayName
        signInAudience = 'AzureADMyOrg'
        api = @{
            requestedAccessTokenVersion = 2
        }
        spa = @{
            redirectUris = $normalizedRedirectUris
        }
        requiredResourceAccess = @(
            @{
                resourceAppId = $BackendAppId
                resourceAccess = @(
                    @{
                        id = $script:BackendAccessScopeId
                        type = 'Scope'
                    }
                )
            },
            @{
                resourceAppId = $script:MicrosoftGraphAppId
                resourceAccess = @(
                    @{
                        id = $GraphUserReadScopeId
                        type = 'Scope'
                    }
                )
            }
        )
    }

    $existing = Get-ApplicationByDisplayName -DisplayName $DisplayName
    $created = $false
    if ($null -eq $existing) {
        $createdApp = Invoke-GraphRequest -Path '/applications' -Method POST -Body $payload
        if ($null -ne $createdApp -and $null -ne $createdApp.id) {
            $app = Get-ApplicationById -Id $createdApp.id
        }
        else {
            $app = Get-ApplicationByDisplayName -DisplayName $DisplayName
        }
        $created = $true
    }
    else {
        Invoke-GraphRequest -Path "/applications/$($existing.id)" -Method PATCH -Body $payload | Out-Null
        $app = Get-ApplicationById -Id $existing.id
    }

    if ($null -eq $app -or $null -eq $app.PSObject.Properties['id']) {
        $app = Get-ApplicationByDisplayName -DisplayName $DisplayName
    }

    if ($null -eq $app -or $null -eq $app.PSObject.Properties['id']) {
        throw "Unable to resolve frontend application '$DisplayName' after create/update."
    }

    Ensure-ApplicationOwner -ApplicationId $app.id -OwnerObjectId $OwnerObjectId

    return [pscustomobject]@{
        Id = $app.id
        AppId = $app.appId
        Created = $created
    }
}

function Ensure-ServicePrincipal {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppId,

        [Parameter(Mandatory = $true)]
        [string]$OwnerObjectId
    )

    $existing = Get-ServicePrincipalByAppId -AppId $AppId
    $created = $false
    if ($null -eq $existing) {
        $createdServicePrincipal = Invoke-GraphRequest -Path '/servicePrincipals' -Method POST -Body @{
            appId = $AppId
        }
        if ($null -ne $createdServicePrincipal -and $null -ne $createdServicePrincipal.id) {
            $servicePrincipal = Get-ServicePrincipalById -Id $createdServicePrincipal.id
        }
        else {
            $servicePrincipal = Get-ServicePrincipalByAppId -AppId $AppId
        }
        $created = $true
    }
    else {
        $servicePrincipal = $existing
    }

    if ($null -eq $servicePrincipal -or $null -eq $servicePrincipal.PSObject.Properties['id']) {
        $servicePrincipal = Get-ServicePrincipalByAppId -AppId $AppId
    }

    if ($null -eq $servicePrincipal -or $null -eq $servicePrincipal.PSObject.Properties['id']) {
        throw "Unable to resolve service principal for appId '$AppId' after create/update."
    }

    Ensure-ServicePrincipalOwner -ServicePrincipalId $servicePrincipal.id -OwnerObjectId $OwnerObjectId

    return [pscustomobject]@{
        Id = $servicePrincipal.id
        AppId = $servicePrincipal.appId
        Created = $created
    }
}

function Ensure-OAuth2PermissionGrant {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClientServicePrincipalId,

        [Parameter(Mandatory = $true)]
        [string]$ResourceServicePrincipalId,

        [Parameter(Mandatory = $true)]
        [string[]]$Scopes
    )

    $scopeValue = ($Scopes | Sort-Object -Unique) -join ' '
    $filter = New-FilterQuery -Filter "clientId eq '$ClientServicePrincipalId' and resourceId eq '$ResourceServicePrincipalId' and consentType eq 'AllPrincipals'"
    $grant = Get-GraphCollection -Path "/oauth2PermissionGrants?`$filter=$filter&`$select=id,scope" | Select-Object -First 1

    if ($null -eq $grant) {
        Invoke-GraphRequest -Path '/oauth2PermissionGrants' -Method POST -Body @{
            clientId = $ClientServicePrincipalId
            consentType = 'AllPrincipals'
            resourceId = $ResourceServicePrincipalId
            scope = $scopeValue
        } | Out-Null
        return
    }

    $currentScopes = @($grant.scope.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries) | Sort-Object -Unique)
    $requiredScopes = @($Scopes | Sort-Object -Unique)
    if (@(Compare-Object -ReferenceObject $currentScopes -DifferenceObject $requiredScopes).Count -eq 0) {
        return
    }

    Invoke-GraphRequest -Path "/oauth2PermissionGrants/$($grant.id)" -Method PATCH -Body @{
        scope = $scopeValue
    } | Out-Null
}

function Ensure-AppRoleAssignment {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('servicePrincipal', 'group')]
        [string]$PrincipalType,

        [Parameter(Mandatory = $true)]
        [string]$PrincipalId,

        [Parameter(Mandatory = $true)]
        [string]$ResourceId,

        [Parameter(Mandatory = $true)]
        [string]$AppRoleId
    )

    $path = if ($PrincipalType -eq 'group') {
        "/groups/$PrincipalId/appRoleAssignments"
    }
    else {
        "/servicePrincipals/$PrincipalId/appRoleAssignments"
    }

    $existingAssignments = Get-GraphCollection -Path "${path}?`$select=id,resourceId,appRoleId"
    $match = $existingAssignments | Where-Object { $_.resourceId -eq $ResourceId -and $_.appRoleId -eq $AppRoleId } | Select-Object -First 1
    if ($null -ne $match) {
        return
    }

    Invoke-GraphRequest -Path $path -Method POST -Body @{
        principalId = $PrincipalId
        resourceId = $ResourceId
        appRoleId = $AppRoleId
    } | Out-Null
}

function Ensure-Group {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $existing = Get-GroupByDisplayName -DisplayName $DisplayName
    $created = $false
    if ($null -eq $existing) {
        $group = Invoke-GraphRequest -Path '/groups' -Method POST -Body @{
            displayName = $DisplayName
            description = $Description
            mailEnabled = $false
            mailNickname = New-SafeMailNickname -DisplayName $DisplayName
            securityEnabled = $true
        }
        $created = $true
    }
    else {
        $group = $existing
    }

    return [pscustomobject]@{
        Id = $group.id
        DisplayName = $DisplayName
        Created = $created
    }
}

function Get-DirectoryRoleDefinition {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    $filter = New-FilterQuery -Filter "displayName eq '$DisplayName'"
    $definition = Get-GraphCollection -Path "/roleManagement/directory/roleDefinitions?`$filter=$filter&`$select=id,displayName" | Select-Object -First 1
    if ($null -eq $definition) {
        throw "Unable to find directory role definition '$DisplayName' in Microsoft Graph."
    }

    return $definition
}

function Ensure-DirectoryRoleAssignment {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RoleDisplayName,

        [Parameter(Mandatory = $true)]
        [string]$PrincipalObjectId
    )

    $definition = Get-DirectoryRoleDefinition -DisplayName $RoleDisplayName
    $filter = New-FilterQuery -Filter "principalId eq '$PrincipalObjectId' and roleDefinitionId eq '$($definition.id)' and directoryScopeId eq '/'"
    $existing = Get-GraphCollection -Path "/roleManagement/directory/roleAssignments?`$filter=$filter&`$select=id,principalId,roleDefinitionId,directoryScopeId" | Select-Object -First 1
    if ($null -ne $existing) {
        return [pscustomobject]@{
            Id = $existing.id
            Created = $false
        }
    }

    $created = Invoke-GraphRequest -Path '/roleManagement/directory/roleAssignments' -Method POST -Body @{
        '@odata.type' = '#microsoft.graph.unifiedRoleAssignment'
        principalId = $PrincipalObjectId
        roleDefinitionId = $definition.id
        directoryScopeId = '/'
    }

    return [pscustomobject]@{
        Id = $created.id
        Created = $true
    }
}

function Normalize-HostName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName
    )

    return $HostName.Trim().TrimEnd('.').ToLowerInvariant()
}

function Get-Sha256Hex {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        $hash = $sha256.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function Get-CustomDomainGuidanceKey {
    param(
        [string[]]$CustomDomains
    )

    if ($null -eq $CustomDomains -or $CustomDomains.Count -eq 0) {
        return ''
    }

    return ((@($CustomDomains | ForEach-Object { Normalize-HostName -HostName $_ }) | Sort-Object -Unique) -join ',')
}

function Get-ManagedCertificateResourceName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName
    )

    $hash = Get-Sha256Hex -Value (Normalize-HostName -HostName $HostName)
    return "asmc-$($hash.Substring(0, 24))"
}

function Get-WebAppResource {
    $subscriptionId = Get-RequiredEnvValue -Name 'AZURE_SUBSCRIPTION_ID'
    $resourceGroup = Get-RequiredEnvValue -Name 'AZURE_RESOURCE_GROUP'
    $siteName = Get-RequiredEnvValue -Name 'SERVICE_WEB_NAME'

    return Invoke-ArmRequest -Path "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/${siteName}?api-version=2023-12-01"
}

function Get-HostNameBinding {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName
    )

    $subscriptionId = Get-RequiredEnvValue -Name 'AZURE_SUBSCRIPTION_ID'
    $resourceGroup = Get-RequiredEnvValue -Name 'AZURE_RESOURCE_GROUP'
    $siteName = Get-RequiredEnvValue -Name 'SERVICE_WEB_NAME'
    $encodedHostName = [System.Uri]::EscapeDataString($HostName)

    return Invoke-ArmRequest -Path "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/${siteName}/hostNameBindings/${encodedHostName}?api-version=2023-12-01" -IgnoreNotFound
}

function Ensure-HostNameBinding {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,

        [string]$SslState = 'Disabled',

        [string]$Thumbprint = ''
    )

    $subscriptionId = Get-RequiredEnvValue -Name 'AZURE_SUBSCRIPTION_ID'
    $resourceGroup = Get-RequiredEnvValue -Name 'AZURE_RESOURCE_GROUP'
    $siteName = Get-RequiredEnvValue -Name 'SERVICE_WEB_NAME'
    $encodedHostName = [System.Uri]::EscapeDataString($HostName)

    $properties = @{
        siteName = $siteName
        hostNameType = 'Verified'
        customHostNameDnsRecordType = 'CName'
        sslState = $SslState
    }

    if (-not [string]::IsNullOrWhiteSpace($Thumbprint)) {
        $properties['thumbprint'] = $Thumbprint
    }

    return Invoke-ArmRequest -Path "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/${siteName}/hostNameBindings/${encodedHostName}?api-version=2023-12-01" -Method PUT -Body @{
        properties = $properties
    }
}

function Get-ManagedCertificate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName
    )

    $subscriptionId = Get-RequiredEnvValue -Name 'AZURE_SUBSCRIPTION_ID'
    $resourceGroup = Get-RequiredEnvValue -Name 'AZURE_RESOURCE_GROUP'
    $certificateName = Get-ManagedCertificateResourceName -HostName $HostName

    return Invoke-ArmRequest -Path "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/certificates/${certificateName}?api-version=2023-12-01" -IgnoreNotFound
}

function Ensure-ManagedCertificate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,

        [Parameter(Mandatory = $true)]
        [string]$ServerFarmId
    )

    $existing = Get-ManagedCertificate -HostName $HostName
    if ($null -ne $existing) {
        return $existing
    }

    $subscriptionId = Get-RequiredEnvValue -Name 'AZURE_SUBSCRIPTION_ID'
    $resourceGroup = Get-RequiredEnvValue -Name 'AZURE_RESOURCE_GROUP'
    $location = Get-RequiredEnvValue -Name 'AZURE_LOCATION'
    $certificateName = Get-ManagedCertificateResourceName -HostName $HostName

    return Invoke-ArmRequest -Path "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/certificates/${certificateName}?api-version=2023-12-01" -Method PUT -Body @{
        location = $location
        properties = @{
            canonicalName = $HostName
            hostNames = @($HostName)
            serverFarmId = $ServerFarmId
        }
    }
}

function Wait-ManagedCertificateReady {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,

        [int]$Attempts = 40,

        [int]$DelaySeconds = 15
    )

    Write-Host "Waiting for the App Service managed certificate for '$HostName'. This commonly takes up to 10 minutes."

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        $certificate = Get-ManagedCertificate -HostName $HostName
        if ($null -ne $certificate -and -not [string]::IsNullOrWhiteSpace($certificate.properties.thumbprint)) {
            return $certificate
        }

        Start-Sleep -Seconds $DelaySeconds
    }

    return $null
}

function Get-NestedPropertyValue {
    param(
        [AllowNull()]
        [object]$Object,

        [Parameter(Mandatory = $true)]
        [string]$PropertyName
    )

    if ($null -eq $Object) {
        return $null
    }

    if ($null -eq $Object.PSObject.Properties[$PropertyName]) {
        return $null
    }

    return $Object.PSObject.Properties[$PropertyName].Value
}

function Get-CurlCommandPath {
    $curlExe = Get-Command -Name 'curl.exe' -ErrorAction SilentlyContinue
    if ($null -ne $curlExe) {
        return $curlExe.Source
    }

    $curlApp = Get-Command -Name 'curl' -CommandType Application -ErrorAction SilentlyContinue
    if ($null -ne $curlApp) {
        return $curlApp.Source
    }

    return $null
}

function Test-TlsEndpoint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,

        [int]$Port = 443,

        [int]$TimeoutSeconds = 30
    )

    $tcpClient = $null
    $sslStream = $null

    try {
        $tcpClient = [System.Net.Sockets.TcpClient]::new()
        $connectTask = $tcpClient.ConnectAsync($HostName, $Port)
        if (-not $connectTask.Wait([TimeSpan]::FromSeconds($TimeoutSeconds))) {
            throw "Timed out connecting to ${HostName}:$Port."
        }

        $sslStream = [System.Net.Security.SslStream]::new($tcpClient.GetStream(), $false)
        $authTask = $sslStream.AuthenticateAsClientAsync($HostName)
        if (-not $authTask.Wait([TimeSpan]::FromSeconds($TimeoutSeconds))) {
            throw "Timed out during TLS handshake with ${HostName}:$Port."
        }

        $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($sslStream.RemoteCertificate)
        return [pscustomobject]@{
            Success = $true
            HostName = $HostName
            Thumbprint = $certificate.Thumbprint
            Subject = $certificate.Subject
            Issuer = $certificate.Issuer
            NotAfter = $certificate.NotAfter
            Error = ''
        }
    }
    catch {
        return [pscustomobject]@{
            Success = $false
            HostName = $HostName
            Thumbprint = ''
            Subject = ''
            Issuer = ''
            NotAfter = $null
            Error = $_.Exception.Message
        }
    }
    finally {
        if ($null -ne $sslStream) {
            $sslStream.Dispose()
        }

        if ($null -ne $tcpClient) {
            $tcpClient.Dispose()
        }
    }
}

function Invoke-HttpGetUsingHttpClient {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [int]$TimeoutSeconds = 30
    )

    $handler = $null
    $client = $null

    try {
        $handler = [System.Net.Http.SocketsHttpHandler]::new()
        $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
        $client = [System.Net.Http.HttpClient]::new($handler)
        $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)
        $response = $client.GetAsync($Uri).GetAwaiter().GetResult()
        $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

        return [pscustomobject]@{
            Success = [int]$response.StatusCode -eq 200
            StatusCode = [int]$response.StatusCode
            Body = $content
            Error = ''
            Client = 'HttpClient'
        }
    }
    catch {
        return [pscustomobject]@{
            Success = $false
            StatusCode = 0
            Body = ''
            Error = $_.Exception.Message
            Client = 'HttpClient'
        }
    }
    finally {
        if ($null -ne $client) {
            $client.Dispose()
        }

        if ($null -ne $handler) {
            $handler.Dispose()
        }
    }
}

function Invoke-HttpGetUsingCurl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [int]$TimeoutSeconds = 30
    )

    $curlPath = Get-CurlCommandPath
    if ([string]::IsNullOrWhiteSpace($curlPath)) {
        return [pscustomobject]@{
            Success = $false
            StatusCode = 0
            Body = ''
            Error = 'curl is not available on this machine.'
            Client = 'curl'
        }
    }

    $output = & $curlPath --silent --show-error --location --max-time $TimeoutSeconds --write-out "`n__STATUS__:%{http_code}" $Uri 2>&1
    $outputText = ($output | Out-String).TrimEnd()
    $statusMarker = '__STATUS__:'
    $statusIndex = $outputText.LastIndexOf($statusMarker, [System.StringComparison]::Ordinal)
    if ($statusIndex -lt 0) {
        return [pscustomobject]@{
            Success = $false
            StatusCode = 0
            Body = ''
            Error = $outputText
            Client = 'curl'
        }
    }

    $body = $outputText.Substring(0, $statusIndex).TrimEnd()
    $statusText = $outputText.Substring($statusIndex + $statusMarker.Length).Trim()
    $statusCode = 0
    [void][int]::TryParse($statusText, [ref]$statusCode)

    return [pscustomobject]@{
        Success = $statusCode -eq 200
        StatusCode = $statusCode
        Body = $body
        Error = ''
        Client = 'curl'
    }
}

function Test-HealthEndpoint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,

        [string]$Path = '/api/general',

        [string]$ExpectedBodySubstring = 'Healthy',

        [int]$TimeoutSeconds = 30
    )

    $uri = "https://${HostName}${Path}"
    $httpResult = Invoke-HttpGetUsingHttpClient -Uri $uri -TimeoutSeconds $TimeoutSeconds
    if (-not $httpResult.Success) {
        $curlResult = Invoke-HttpGetUsingCurl -Uri $uri -TimeoutSeconds $TimeoutSeconds
        if ($curlResult.Success) {
            $bodyMatches = [string]::IsNullOrWhiteSpace($ExpectedBodySubstring) -or $curlResult.Body -like "*$ExpectedBodySubstring*"
            return [pscustomobject]@{
                Success = $bodyMatches
                StatusCode = $curlResult.StatusCode
                Body = $curlResult.Body
                Error = if ($bodyMatches) { '' } else { "HTTP 200 received from curl, but the body did not contain '$ExpectedBodySubstring'." }
                Client = $curlResult.Client
            }
        }

        return [pscustomobject]@{
            Success = $false
            StatusCode = 0
            Body = ''
            Error = "HttpClient failed: $($httpResult.Error) | curl failed: $($curlResult.Error)"
            Client = 'HttpClient+curl'
        }
    }

    $bodyMatches = [string]::IsNullOrWhiteSpace($ExpectedBodySubstring) -or $httpResult.Body -like "*$ExpectedBodySubstring*"
    return [pscustomobject]@{
        Success = $bodyMatches
        StatusCode = $httpResult.StatusCode
        Body = $httpResult.Body
        Error = if ($bodyMatches) { '' } else { "HTTP 200 received from HttpClient, but the body did not contain '$ExpectedBodySubstring'." }
        Client = $httpResult.Client
    }
}

function Wait-CustomDomainEndpointReady {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,

        [string]$ExpectedThumbprint = '',

        [int]$Attempts = 20,

        [int]$DelaySeconds = 15
    )

    $lastTlsResult = $null
    $lastHealthResult = $null

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        $lastTlsResult = Test-TlsEndpoint -HostName $HostName
        $lastHealthResult = Test-HealthEndpoint -HostName $HostName

        $thumbprintMatches = [string]::IsNullOrWhiteSpace($ExpectedThumbprint) -or (
            $lastTlsResult.Success -and
            [string]::Equals($lastTlsResult.Thumbprint, $ExpectedThumbprint, [System.StringComparison]::OrdinalIgnoreCase)
        )

        if ($lastTlsResult.Success -and $thumbprintMatches -and $lastHealthResult.Success) {
            return [pscustomobject]@{
                Success = $true
                Tls = $lastTlsResult
                Health = $lastHealthResult
            }
        }

        if ($attempt -lt $Attempts) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    return [pscustomobject]@{
        Success = $false
        Tls = $lastTlsResult
        Health = $lastHealthResult
    }
}

function Get-DnsTxtValues {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (Get-Command -Name Resolve-DnsName -ErrorAction SilentlyContinue) {
        return @(
            Resolve-DnsName -Name $Name -Type TXT -ErrorAction SilentlyContinue |
            ForEach-Object {
                if ($null -ne $_ -and $null -ne $_.PSObject.Properties['Strings']) {
                    $_.Strings
                }
                elseif ($null -ne $_ -and $null -ne $_.PSObject.Properties['Text']) {
                    $_.Text
                }
            } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
    }

    if (Get-Command -Name dig -ErrorAction SilentlyContinue) {
        return @(
            (& dig +short TXT $Name 2>$null) |
            ForEach-Object { $_.Trim().Trim('"') } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
    }

    if (Get-Command -Name nslookup -ErrorAction SilentlyContinue) {
        return @(
            (& nslookup -type=TXT $Name 2>$null) |
            ForEach-Object {
                if ($_ -match 'text\s*=\s*"(?<value>.+)"') {
                    $matches['value']
                }
            } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
    }

    throw 'Unable to validate custom domain TXT records because neither Resolve-DnsName, dig, nor nslookup is available on this machine.'
}

function Get-DnsCNameTarget {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (Get-Command -Name Resolve-DnsName -ErrorAction SilentlyContinue) {
        $record = Resolve-DnsName -Name $Name -Type CNAME -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $record -and $null -ne $record.PSObject.Properties['NameHost'] -and -not [string]::IsNullOrWhiteSpace($record.NameHost)) {
            return Normalize-HostName -HostName $record.NameHost
        }
    }

    if (Get-Command -Name dig -ErrorAction SilentlyContinue) {
        $record = (& dig +short CNAME $Name 2>$null | Select-Object -First 1)
        if (-not [string]::IsNullOrWhiteSpace($record)) {
            return Normalize-HostName -HostName $record
        }
    }

    if (Get-Command -Name nslookup -ErrorAction SilentlyContinue) {
        $record = (& nslookup -type=CNAME $Name 2>$null | Select-String -Pattern 'canonical name = (?<value>.+)$' | Select-Object -First 1)
        if ($null -ne $record) {
            return Normalize-HostName -HostName $record.Matches[0].Groups['value'].Value
        }
    }

    return ''
}

function Get-CustomDomainDnsState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,

        [Parameter(Mandatory = $true)]
        [string]$VerificationId,

        [Parameter(Mandatory = $true)]
        [string]$DefaultHostname
    )

    $normalizedHostName = Normalize-HostName -HostName $HostName
    if ($normalizedHostName.Contains('*')) {
        throw "Wildcard custom domains are not supported by the automated custom-domain hook. Configure '$HostName' manually."
    }

    $txtRecordName = "asuid.$normalizedHostName"
    $txtValues = @(Get-DnsTxtValues -Name $txtRecordName)
    $cnameTarget = Get-DnsCNameTarget -Name $normalizedHostName
    $expectedCName = Normalize-HostName -HostName $DefaultHostname
    $expectedVerificationId = $VerificationId.Trim()
    $matchesTxt = $txtValues -contains $expectedVerificationId
    $matchesCName = -not [string]::IsNullOrWhiteSpace($cnameTarget) -and $cnameTarget -eq $expectedCName

    return [pscustomobject]@{
        HostName = $normalizedHostName
        TxtRecordName = $txtRecordName
        ExpectedTxtValue = $expectedVerificationId
        CurrentTxtValues = $txtValues
        ExpectedCName = $expectedCName
        CurrentCName = $cnameTarget
        IsValid = $matchesTxt -and $matchesCName
    }
}

function Write-CustomDomainGuidance {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$PendingDomains,

        [Parameter(Mandatory = $true)]
        [bool]$FailOnMismatch,

        [Parameter(Mandatory = $true)]
        [bool]$EnableManagedCertificate
    )

    if ($null -eq $PendingDomains -or $PendingDomains.Count -eq 0) {
        return
    }

    $nextAction = if ($FailOnMismatch) {
        'Custom domain DNS validation did not pass on the follow-up run.'
    }
    else {
        'Custom domain DNS validation is pending.'
    }

    Write-Host $nextAction
    foreach ($pending in $PendingDomains) {
        Write-Host "- Requested hostname: $($pending.HostName)"
        Write-Host "  TXT: $($pending.TxtRecordName) = $($pending.ExpectedTxtValue)"
        Write-Host "  CNAME: $($pending.HostName) -> $($pending.ExpectedCName)"
        if (@($pending.CurrentTxtValues).Count -gt 0) {
            Write-Host "  Current TXT values: $((@($pending.CurrentTxtValues) -join ', '))"
        }
        else {
            Write-Host '  Current TXT values: none found'
        }

        if ([string]::IsNullOrWhiteSpace($pending.CurrentCName)) {
            Write-Host '  Current CNAME target: none found'
        }
        else {
            Write-Host "  Current CNAME target: $($pending.CurrentCName)"
        }
    }

    if ($EnableManagedCertificate) {
        Write-Host 'After both DNS records resolve correctly, rerun azd provision to bind the hostname and request the App Service managed certificate.'
    }
    else {
        Write-Host 'After both DNS records resolve correctly, rerun azd provision to bind the hostname. HTTPS will still require you to upload and bind a certificate manually.'
    }

    Write-Host 'The automated custom-domain flow currently assumes CNAME-based subdomains. Apex/root domains should still be completed manually.'
}

function Write-CustomDomainEndpointValidationGuidance {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$PendingDomains
    )

    if ($null -eq $PendingDomains -or $PendingDomains.Count -eq 0) {
        return
    }

    Write-Host 'Custom domain HTTPS validation is still pending.'
    foreach ($pending in $PendingDomains) {
        Write-Host "- Hostname: $($pending.HostName)"
        if ($null -ne $pending.Tls -and -not $pending.Tls.Success) {
            Write-Host "  TLS: $($pending.Tls.Error)"
        }
        elseif ($null -ne $pending.Tls -and -not [string]::IsNullOrWhiteSpace($pending.ExpectedThumbprint) -and -not [string]::Equals($pending.Tls.Thumbprint, $pending.ExpectedThumbprint, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Host "  TLS: expected thumbprint $($pending.ExpectedThumbprint), current thumbprint $($pending.Tls.Thumbprint)"
        }

        if ($null -ne $pending.Health -and -not $pending.Health.Success) {
            Write-Host "  Health: $($pending.Health.Error)"
        }
        elseif ($null -ne $pending.Health) {
            Write-Host "  Health: received HTTP $($pending.Health.StatusCode) via $($pending.Health.Client), but the response body validation did not pass."
        }
    }

    Write-Host 'Azure may still be propagating the new hostname binding or managed certificate. Rerun azd provision in a few minutes.'
}

function Ensure-CustomDomains {
    param(
        [string[]]$CustomDomains
    )

    if ($null -eq $CustomDomains -or $CustomDomains.Count -eq 0) {
        Set-AzdEnvironmentValue -Name 'MYWORKID_CUSTOM_DOMAIN_CONFIGURATION_STATUS' -Value 'notConfigured'
        Set-AzdEnvironmentValue -Name 'MYWORKID_CUSTOM_DOMAIN_PENDING_HOSTNAMES' -Value ''
        Set-AzdEnvironmentValue -Name 'MYWORKID_CUSTOM_DOMAIN_DNS_GUIDANCE_FOR' -Value ''
        return
    }

    $enableManagedCertificate = ConvertTo-Boolean -Value (Get-OptionalEnvValue -Name 'MYWORKID_ENABLE_APP_SERVICE_MANAGED_CERTIFICATE' -Default 'true')
    $defaultHostname = Get-RequiredEnvValue -Name 'MYWORKID_APP_SERVICE_DEFAULT_HOSTNAME'
    $verificationId = Get-RequiredEnvValue -Name 'MYWORKID_APP_SERVICE_CUSTOM_DOMAIN_VERIFICATION_ID'
    $guidanceKey = Get-CustomDomainGuidanceKey -CustomDomains $CustomDomains
    $guidanceShownFor = Get-OptionalEnvValue -Name 'MYWORKID_CUSTOM_DOMAIN_DNS_GUIDANCE_FOR'
    $failOnMismatch = $guidanceShownFor -eq $guidanceKey
    $site = Get-WebAppResource
    $serverFarmId = $site.properties.serverFarmId

    $pendingDomains = New-Object System.Collections.Generic.List[object]
    $certificatePendingHostNames = New-Object System.Collections.Generic.List[string]
    $endpointPendingDomains = New-Object System.Collections.Generic.List[object]

    foreach ($customDomain in @($CustomDomains | ForEach-Object { Normalize-HostName -HostName $_ } | Sort-Object -Unique)) {
        $binding = Get-HostNameBinding -HostName $customDomain
        $bindingProperties = Get-NestedPropertyValue -Object $binding -PropertyName 'properties'
        $bindingSslState = Get-NestedPropertyValue -Object $bindingProperties -PropertyName 'sslState'
        $bindingThumbprint = Get-NestedPropertyValue -Object $bindingProperties -PropertyName 'thumbprint'
        $bindingHasTls = $null -ne $binding -and $bindingSslState -eq 'SniEnabled' -and -not [string]::IsNullOrWhiteSpace($bindingThumbprint)
        $bindingExists = $null -ne $binding

        if (-not $bindingExists) {
            $dnsState = Get-CustomDomainDnsState -HostName $customDomain -VerificationId $verificationId -DefaultHostname $defaultHostname
            if (-not $dnsState.IsValid) {
                $pendingDomains.Add($dnsState)
                continue
            }

            $binding = Ensure-HostNameBinding -HostName $customDomain
            $bindingExists = $true
            $bindingProperties = Get-NestedPropertyValue -Object $binding -PropertyName 'properties'
            $bindingSslState = Get-NestedPropertyValue -Object $bindingProperties -PropertyName 'sslState'
            $bindingThumbprint = Get-NestedPropertyValue -Object $bindingProperties -PropertyName 'thumbprint'
            $bindingHasTls = $bindingSslState -eq 'SniEnabled' -and -not [string]::IsNullOrWhiteSpace($bindingThumbprint)
        }

        if (-not $enableManagedCertificate) {
            continue
        }

        $certificateThumbprint = $bindingThumbprint
        if (-not $bindingHasTls) {
            Ensure-ManagedCertificate -HostName $customDomain -ServerFarmId $serverFarmId | Out-Null
            $certificate = Wait-ManagedCertificateReady -HostName $customDomain
            $certificateProperties = Get-NestedPropertyValue -Object $certificate -PropertyName 'properties'
            $certificateThumbprint = Get-NestedPropertyValue -Object $certificateProperties -PropertyName 'thumbprint'
            if ($null -eq $certificate -or [string]::IsNullOrWhiteSpace($certificateThumbprint)) {
                $certificatePendingHostNames.Add($customDomain)
                continue
            }

            Ensure-HostNameBinding -HostName $customDomain -SslState 'SniEnabled' -Thumbprint $certificateThumbprint | Out-Null
        }

        $endpointValidation = Wait-CustomDomainEndpointReady -HostName $customDomain -ExpectedThumbprint $certificateThumbprint
        if (-not $endpointValidation.Success) {
            $endpointPendingDomains.Add([pscustomobject]@{
                HostName = $customDomain
                ExpectedThumbprint = $certificateThumbprint
                Tls = $endpointValidation.Tls
                Health = $endpointValidation.Health
            })
        }
    }

    if ($pendingDomains.Count -gt 0) {
        Set-AzdEnvironmentValue -Name 'MYWORKID_CUSTOM_DOMAIN_CONFIGURATION_STATUS' -Value 'awaitingDns'
        Set-AzdEnvironmentValue -Name 'MYWORKID_CUSTOM_DOMAIN_PENDING_HOSTNAMES' -Value (($pendingDomains | ForEach-Object { $_.HostName }) -join ',')
        Set-AzdEnvironmentValue -Name 'MYWORKID_CUSTOM_DOMAIN_DNS_GUIDANCE_FOR' -Value $guidanceKey
        Write-CustomDomainGuidance -PendingDomains $pendingDomains.ToArray() -FailOnMismatch $failOnMismatch -EnableManagedCertificate $enableManagedCertificate

        if ($failOnMismatch) {
            throw 'Custom domain DNS validation failed on the follow-up run. Fix the TXT/CNAME records shown above and rerun azd provision.'
        }

        return
    }

    if ($certificatePendingHostNames.Count -gt 0) {
        Set-AzdEnvironmentValue -Name 'MYWORKID_CUSTOM_DOMAIN_CONFIGURATION_STATUS' -Value 'awaitingManagedCertificate'
        Set-AzdEnvironmentValue -Name 'MYWORKID_CUSTOM_DOMAIN_PENDING_HOSTNAMES' -Value (($certificatePendingHostNames.ToArray()) -join ',')
        Set-AzdEnvironmentValue -Name 'MYWORKID_CUSTOM_DOMAIN_DNS_GUIDANCE_FOR' -Value ''
        Write-Host "Managed certificate issuance is still pending for: $(($certificatePendingHostNames.ToArray()) -join ', '). It is common for App Service managed certificates to take up to 10 minutes. Rerun azd provision in a few minutes to complete the HTTPS binding."
        return
    }

    if ($endpointPendingDomains.Count -gt 0) {
        Set-AzdEnvironmentValue -Name 'MYWORKID_CUSTOM_DOMAIN_CONFIGURATION_STATUS' -Value 'awaitingHttpsValidation'
        Set-AzdEnvironmentValue -Name 'MYWORKID_CUSTOM_DOMAIN_PENDING_HOSTNAMES' -Value (($endpointPendingDomains.ToArray() | ForEach-Object { $_.HostName }) -join ',')
        Set-AzdEnvironmentValue -Name 'MYWORKID_CUSTOM_DOMAIN_DNS_GUIDANCE_FOR' -Value ''
        Write-CustomDomainEndpointValidationGuidance -PendingDomains $endpointPendingDomains.ToArray()
        return
    }

    Set-AzdEnvironmentValue -Name 'MYWORKID_CUSTOM_DOMAIN_CONFIGURATION_STATUS' -Value 'configured'
    Set-AzdEnvironmentValue -Name 'MYWORKID_CUSTOM_DOMAIN_PENDING_HOSTNAMES' -Value ''
    Set-AzdEnvironmentValue -Name 'MYWORKID_CUSTOM_DOMAIN_DNS_GUIDANCE_FOR' -Value ''
}

function Register-RequiredProviders {
    $subscriptionId = Get-RequiredEnvValue -Name 'AZURE_SUBSCRIPTION_ID'
    foreach ($namespace in $script:ProviderNamespaces) {
        Invoke-ArmRequest -Path "/subscriptions/$subscriptionId/providers/$namespace/register?api-version=2021-04-01" -Method POST | Out-Null
    }
}

function Remove-GraphResourceIfCreated {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CreatedFlagName,

        [Parameter(Mandatory = $true)]
        [string]$IdName,

        [Parameter(Mandatory = $true)]
        [string]$PathPrefix
    )

    if (-not (ConvertTo-Boolean -Value (Get-OptionalEnvValue -Name $CreatedFlagName -Default 'false'))) {
        return
    }

    $id = Get-OptionalEnvValue -Name $IdName
    if ([string]::IsNullOrWhiteSpace($id)) {
        return
    }

    Invoke-GraphRequest -Path "$PathPrefix/$id" -Method DELETE -IgnoreNotFound | Out-Null
}

function Remove-DirectoryRoleAssignmentIfCreated {
    $created = ConvertTo-Boolean -Value (Get-OptionalEnvValue -Name 'MYWORKID_MANAGED_IDENTITY_DIRECTORY_ROLE_ASSIGNMENT_CREATED' -Default 'false')
    if (-not $created) {
        return
    }

    $assignmentId = Get-OptionalEnvValue -Name 'MYWORKID_MANAGED_IDENTITY_DIRECTORY_ROLE_ASSIGNMENT_ID'
    if ([string]::IsNullOrWhiteSpace($assignmentId)) {
        return
    }

    Invoke-GraphRequest -Path "/roleManagement/directory/roleAssignments/$assignmentId" -Method DELETE -IgnoreNotFound | Out-Null
}

function Invoke-MyWorkIDPreProvision {
    Import-AzdEnvironment
    Ensure-TemplateDefaults
    Register-RequiredProviders

    $ownerObjectId = Get-CurrentUserId
    $backendDisplayName = Get-RequiredEnvValue -Name 'MYWORKID_BACKED_APPREG_NAME'
    $frontendDisplayName = Get-RequiredEnvValue -Name 'MYWORKID_FRONTEND_APPREG_NAME'
    $devRedirectUris = @(Split-CommaList -Value (Get-OptionalEnvValue -Name 'MYWORKID_DEV_REDIRECT_URLS'))

    $graphServicePrincipal = Get-ServicePrincipalByAppId -AppId $script:MicrosoftGraphAppId
    $graphUserReadScopeId = ($graphServicePrincipal.oauth2PermissionScopes | Where-Object { $_.value -eq 'User.Read' } | Select-Object -First 1).id
    if ([string]::IsNullOrWhiteSpace($graphUserReadScopeId)) {
        throw 'Unable to resolve the Microsoft Graph User.Read delegated scope.'
    }

    $backendApplication = Ensure-BackendApplication -DisplayName $backendDisplayName -OwnerObjectId $ownerObjectId
    $backendServicePrincipal = Ensure-ServicePrincipal -AppId $backendApplication.AppId -OwnerObjectId $ownerObjectId

    $frontendApplication = Ensure-FrontendApplication `
        -DisplayName $frontendDisplayName `
        -OwnerObjectId $ownerObjectId `
        -BackendAppId $backendApplication.AppId `
        -GraphUserReadScopeId $graphUserReadScopeId `
        -RedirectUris $devRedirectUris
    $frontendServicePrincipal = Ensure-ServicePrincipal -AppId $frontendApplication.AppId -OwnerObjectId $ownerObjectId

    Set-AzdEnvironmentValue -Name 'MYWORKID_BACKEND_APPLICATION_ID' -Value $backendApplication.Id
    Set-AzdEnvironmentValue -Name 'MYWORKID_BACKEND_APPLICATION_CREATED' -Value $backendApplication.Created.ToString().ToLowerInvariant()
    Set-AzdEnvironmentValue -Name 'MYWORKID_BACKEND_CLIENT_ID' -Value $backendApplication.AppId
    Set-AzdEnvironmentValue -Name 'MYWORKID_BACKEND_SERVICE_PRINCIPAL_ID' -Value $backendServicePrincipal.Id
    Set-AzdEnvironmentValue -Name 'MYWORKID_BACKEND_SERVICE_PRINCIPAL_CREATED' -Value $backendServicePrincipal.Created.ToString().ToLowerInvariant()

    Set-AzdEnvironmentValue -Name 'MYWORKID_FRONTEND_APPLICATION_ID' -Value $frontendApplication.Id
    Set-AzdEnvironmentValue -Name 'MYWORKID_FRONTEND_APPLICATION_CREATED' -Value $frontendApplication.Created.ToString().ToLowerInvariant()
    Set-AzdEnvironmentValue -Name 'MYWORKID_FRONTEND_CLIENT_ID' -Value $frontendApplication.AppId
    Set-AzdEnvironmentValue -Name 'MYWORKID_FRONTEND_SERVICE_PRINCIPAL_ID' -Value $frontendServicePrincipal.Id
    Set-AzdEnvironmentValue -Name 'MYWORKID_FRONTEND_SERVICE_PRINCIPAL_CREATED' -Value $frontendServicePrincipal.Created.ToString().ToLowerInvariant()
}

function Invoke-MyWorkIDPostProvision {
    $step = 'initialization'
    try {
        Import-AzdEnvironment

        $step = 'load service principals'
        $ownerObjectId = Get-CurrentUserId
        $backendClientId = Get-RequiredEnvValue -Name 'MYWORKID_BACKEND_CLIENT_ID'
        $frontendClientId = Get-RequiredEnvValue -Name 'MYWORKID_FRONTEND_CLIENT_ID'

        $backendServicePrincipal = Get-ServicePrincipalByAppId -AppId $backendClientId
        $frontendServicePrincipal = Get-ServicePrincipalByAppId -AppId $frontendClientId
        if ($null -eq $backendServicePrincipal -or $null -eq $frontendServicePrincipal) {
            throw 'The MyWorkID application service principals were not found. Run azd provision again after the preprovision hook succeeds.'
        }

        $step = 'ensure service principal owners'
        Ensure-ServicePrincipalOwner -ServicePrincipalId $backendServicePrincipal.id -OwnerObjectId $ownerObjectId
        Ensure-ServicePrincipalOwner -ServicePrincipalId $frontendServicePrincipal.id -OwnerObjectId $ownerObjectId

        $step = 'configure frontend redirect uris'
        $frontendApplicationId = Get-RequiredEnvValue -Name 'MYWORKID_FRONTEND_APPLICATION_ID'
        $customDomains = @(Split-CommaList -Value (Get-OptionalEnvValue -Name 'MYWORKID_CUSTOM_DOMAINS'))
        $devRedirectUris = @(Split-CommaList -Value (Get-OptionalEnvValue -Name 'MYWORKID_DEV_REDIRECT_URLS'))
        $defaultHostname = Get-RequiredEnvValue -Name 'MYWORKID_APP_SERVICE_DEFAULT_HOSTNAME'
        $redirectUris = @("https://$defaultHostname")
        $redirectUris += $customDomains | ForEach-Object { "https://$_" }
        $redirectUris += $devRedirectUris
        $redirectUris = @($redirectUris | ForEach-Object { Ensure-TrailingSlash -Uri $_ } | Sort-Object -Unique)

        Invoke-GraphRequest -Path "/applications/$frontendApplicationId" -Method PATCH -Body @{
            spa = @{
                redirectUris = $redirectUris
            }
        } | Out-Null

        $step = 'configure custom domains'
        Ensure-CustomDomains -CustomDomains $customDomains

        if (ConvertTo-Boolean -Value (Get-OptionalEnvValue -Name 'MYWORKID_SKIP_ACTIONS_REQUIRING_GLOBAL_ADMIN' -Default 'false')) {
            Write-Host 'Skipping Global Admin dependent Graph grants and directory role assignments because skip_actions_requiring_global_admin=true.'
            return
        }

        $step = 'load graph service principals'
        $microsoftGraphServicePrincipal = Get-ServicePrincipalByAppId -AppId $script:MicrosoftGraphAppId
        $verifiableCredentialsServicePrincipal = Get-ServicePrincipalByAppId -AppId $script:VerifiableCredentialsAppId
        $managedIdentityPrincipalId = Get-RequiredEnvValue -Name 'MYWORKID_MANAGED_IDENTITY_PRINCIPAL_ID'

        $step = 'grant frontend access to backend'
        Ensure-OAuth2PermissionGrant -ClientServicePrincipalId $frontendServicePrincipal.id -ResourceServicePrincipalId $backendServicePrincipal.id -Scopes @('openid', 'Access')

        $step = 'grant frontend access to microsoft graph'
        Ensure-OAuth2PermissionGrant -ClientServicePrincipalId $frontendServicePrincipal.id -ResourceServicePrincipalId $microsoftGraphServicePrincipal.id -Scopes @('User.Read')

        $step = 'resolve graph app role ids'
        $graphAppRoleIds = @{
            'IdentityRiskyUser.ReadWrite.All' = ($microsoftGraphServicePrincipal.appRoles | Where-Object { $_.value -eq 'IdentityRiskyUser.ReadWrite.All' } | Select-Object -First 1).id
            'CustomSecAttributeAssignment.ReadWrite.All' = ($microsoftGraphServicePrincipal.appRoles | Where-Object { $_.value -eq 'CustomSecAttributeAssignment.ReadWrite.All' } | Select-Object -First 1).id
        }

        foreach ($permission in $graphAppRoleIds.GetEnumerator()) {
            if ([string]::IsNullOrWhiteSpace($permission.Value)) {
                throw "Unable to resolve Microsoft Graph app role '$($permission.Key)'."
            }

            $step = "assign managed identity graph role $($permission.Key)"
            Ensure-AppRoleAssignment -PrincipalType servicePrincipal -PrincipalId $managedIdentityPrincipalId -ResourceId $microsoftGraphServicePrincipal.id -AppRoleId $permission.Value
        }

        $step = 'assign managed identity verifiable credentials role'
        Ensure-AppRoleAssignment -PrincipalType servicePrincipal -PrincipalId $managedIdentityPrincipalId -ResourceId $verifiableCredentialsServicePrincipal.id -AppRoleId $script:VerifiableCredentialsCreateAllRoleId

        $step = 'assign directory role'
        $roleDisplayName = if (ConvertTo-Boolean -Value (Get-OptionalEnvValue -Name 'MYWORKID_ALLOW_CREDENTIAL_OPERATIONS_FOR_PRIVILEGED_USERS' -Default 'false')) {
            'Privileged Authentication Administrator'
        }
        else {
            'Authentication Administrator'
        }

        try {
            $directoryRoleAssignment = Ensure-DirectoryRoleAssignment -RoleDisplayName $roleDisplayName -PrincipalObjectId $managedIdentityPrincipalId
            $roleAssignmentCreated = (ConvertTo-Boolean -Value (Get-OptionalEnvValue -Name 'MYWORKID_MANAGED_IDENTITY_DIRECTORY_ROLE_ASSIGNMENT_CREATED' -Default 'false')) -or $directoryRoleAssignment.Created
            Set-AzdEnvironmentValue -Name 'MYWORKID_MANAGED_IDENTITY_DIRECTORY_ROLE_ASSIGNMENT_ID' -Value $directoryRoleAssignment.Id
            Set-AzdEnvironmentValue -Name 'MYWORKID_MANAGED_IDENTITY_DIRECTORY_ROLE_ASSIGNMENT_CREATED' -Value $roleAssignmentCreated.ToString().ToLowerInvariant()
        }
        catch {
            Write-Warning "Unable to assign directory role '$roleDisplayName' to managed identity '$managedIdentityPrincipalId' automatically. Complete this step manually if TAP or password reset flows need it. Details: $($_.Exception.Message)"
        }

        if (ConvertTo-Boolean -Value (Get-OptionalEnvValue -Name 'MYWORKID_SKIP_CREATION_BACKEND_ACCESS_GROUPS' -Default 'false')) {
            Write-Host 'Skipping backend access group creation because skip_creation_backend_access_groups=true.'
            return
        }

        $step = 'ensure backend access groups'
        $groupDefinitions = @(
            @{
                EnvName = 'MYWORKID_CREATE_TAP_GROUP_NAME'
                Description = 'Access group for MyWorkID backend permission MyWorkID.CreateTAP'
                AppRoleId = $script:CreateTapRoleId
                IdName = 'MYWORKID_CREATE_TAP_GROUP_ID'
                CreatedName = 'MYWORKID_CREATE_TAP_GROUP_CREATED'
            },
            @{
                EnvName = 'MYWORKID_DISMISS_USER_RISK_GROUP_NAME'
                Description = 'Access group for MyWorkID backend permission MyWorkID.DismissUserRisk'
                AppRoleId = $script:DismissUserRiskRoleId
                IdName = 'MYWORKID_DISMISS_USER_RISK_GROUP_ID'
                CreatedName = 'MYWORKID_DISMISS_USER_RISK_GROUP_CREATED'
            },
            @{
                EnvName = 'MYWORKID_PASSWORD_RESET_GROUP_NAME'
                Description = 'Access group for MyWorkID backend permission MyWorkID.PasswordReset'
                AppRoleId = $script:PasswordResetRoleId
                IdName = 'MYWORKID_PASSWORD_RESET_GROUP_ID'
                CreatedName = 'MYWORKID_PASSWORD_RESET_GROUP_CREATED'
            },
            @{
                EnvName = 'MYWORKID_VALIDATE_IDENTITY_GROUP_NAME'
                Description = 'Access group for MyWorkID backend permission MyWorkID.ValidateIdentity'
                AppRoleId = $script:ValidateIdentityRoleId
                IdName = 'MYWORKID_VALIDATE_IDENTITY_GROUP_ID'
                CreatedName = 'MYWORKID_VALIDATE_IDENTITY_GROUP_CREATED'
            }
        )

        foreach ($definition in $groupDefinitions) {
            $displayName = Get-OptionalEnvValue -Name $definition.EnvName
            if ([string]::IsNullOrWhiteSpace($displayName)) {
                continue
            }

            $step = "ensure backend access group $displayName"
            $group = Ensure-Group -DisplayName $displayName -Description $definition.Description
            Ensure-AppRoleAssignment -PrincipalType group -PrincipalId $group.Id -ResourceId $backendServicePrincipal.id -AppRoleId $definition.AppRoleId

            Set-AzdEnvironmentValue -Name $definition.IdName -Value $group.Id
            Set-AzdEnvironmentValue -Name $definition.CreatedName -Value $group.Created.ToString().ToLowerInvariant()
        }
    }
    catch {
        throw "Postprovision failed during '$step': $($_.Exception.Message)"
    }
}

function Invoke-MyWorkIDPreDown {
    Import-AzdEnvironment

    Remove-DirectoryRoleAssignmentIfCreated
    Remove-GraphResourceIfCreated -CreatedFlagName 'MYWORKID_VALIDATE_IDENTITY_GROUP_CREATED' -IdName 'MYWORKID_VALIDATE_IDENTITY_GROUP_ID' -PathPrefix '/groups'
    Remove-GraphResourceIfCreated -CreatedFlagName 'MYWORKID_PASSWORD_RESET_GROUP_CREATED' -IdName 'MYWORKID_PASSWORD_RESET_GROUP_ID' -PathPrefix '/groups'
    Remove-GraphResourceIfCreated -CreatedFlagName 'MYWORKID_DISMISS_USER_RISK_GROUP_CREATED' -IdName 'MYWORKID_DISMISS_USER_RISK_GROUP_ID' -PathPrefix '/groups'
    Remove-GraphResourceIfCreated -CreatedFlagName 'MYWORKID_CREATE_TAP_GROUP_CREATED' -IdName 'MYWORKID_CREATE_TAP_GROUP_ID' -PathPrefix '/groups'

    Remove-GraphResourceIfCreated -CreatedFlagName 'MYWORKID_FRONTEND_SERVICE_PRINCIPAL_CREATED' -IdName 'MYWORKID_FRONTEND_SERVICE_PRINCIPAL_ID' -PathPrefix '/servicePrincipals'
    Remove-GraphResourceIfCreated -CreatedFlagName 'MYWORKID_BACKEND_SERVICE_PRINCIPAL_CREATED' -IdName 'MYWORKID_BACKEND_SERVICE_PRINCIPAL_ID' -PathPrefix '/servicePrincipals'

    Remove-GraphResourceIfCreated -CreatedFlagName 'MYWORKID_FRONTEND_APPLICATION_CREATED' -IdName 'MYWORKID_FRONTEND_APPLICATION_ID' -PathPrefix '/applications'
    Remove-GraphResourceIfCreated -CreatedFlagName 'MYWORKID_BACKEND_APPLICATION_CREATED' -IdName 'MYWORKID_BACKEND_APPLICATION_ID' -PathPrefix '/applications'
}
