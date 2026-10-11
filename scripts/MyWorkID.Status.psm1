#Requires -Version 7.6
Set-StrictMode -Version Latest

# This module deliberately does not import provisioning hooks or azd environments.
function Get-MwidCachedContext {
    param($Target)
    $text = & az account show --output json --only-show-errors 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'AccountUnavailable' }
    $account = $text | ConvertFrom-Json -DateKind String
    if ($account.id -ne $Target.subscriptionId -or $account.tenantId -ne $Target.tenantId -or
        $account.user.type -ne 'user' -or $account.user.name -ne $Target.account) { throw 'AccountMismatch' }
}

function Get-MwidReadToken {
    param($Target, [ValidateSet('arm','graph')]$Service)
    $resource = if ($Service -eq 'arm') { 'https://management.azure.com/' } else { 'https://graph.microsoft.com/' }
    $text = & az account get-access-token --subscription $Target.subscriptionId --resource $resource --output json --only-show-errors 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'ReadUnavailable' }
    try {
        $token = ($text | ConvertFrom-Json -DateKind String).accessToken
        $part = $token.Split('.')[1].Replace('-','+').Replace('_','/')
        $part = $part.PadRight($part.Length + ((4 - $part.Length % 4) % 4), '=')
        $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($part)) | ConvertFrom-Json -DateKind String
        $audiences = if ($Service -eq 'arm') { @('https://management.azure.com', 'https://management.azure.com/', 'https://management.core.windows.net/') } else { @('https://graph.microsoft.com', 'https://graph.microsoft.com/', '00000003-0000-0000-c000-000000000000') }
        if (-not $claims.PSObject.Properties['scp'] -or [string]::IsNullOrWhiteSpace($claims.scp) -or $claims.tid -ne $Target.tenantId -or $claims.oid -ne $Target.accountObjectId -or $claims.aud -notin $audiences -or
            [long]$claims.exp -le [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) { throw 'TokenMismatch' }
        return $token
    } catch { throw 'ReadUnavailable' }
}

function Read-MwidApi {
    param($Target, [ValidateSet('arm','graph')]$Service, [string]$Path)
    $base = if ($Service -eq 'arm') { 'https://management.azure.com' } else { 'https://graph.microsoft.com/v1.0' }
    if ($Path -notmatch '^/[A-Za-z0-9/?$=,() .%&''_-]+$' -or $Path.Contains('..') -or
        ($Service -eq 'arm' -and -not $Path.StartsWith("/subscriptions/$($Target.subscriptionId)/resourceGroups/$($Target.resourceGroup)/", [StringComparison]::OrdinalIgnoreCase))) { throw 'ReadBindingFailed' }
    $token = Get-MwidReadToken $Target $Service
    try {
        $response = Invoke-WebRequest -Uri ($base + $Path) -Method Get -Headers @{ Authorization = "Bearer $token" } -MaximumRedirection 0 -TimeoutSec 20 -ErrorAction Stop
    } catch {
        $code = if ($_.Exception.PSObject.Properties['Response'] -and $_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
        if ($code -eq 404) { return $null }
        if ($code -in @(401,403,429,500,502,503,504) -or $code -eq 0) { throw 'ReadUnavailable' }
        throw 'ReadFailed'
    }
    try { return $response.Content | ConvertFrom-Json -DateKind String -Depth 64 } catch { throw 'ReadFailed' }
}

function Read-MwidCollection {
    param($Target, [string]$Path)
    $page = Read-MwidApi $Target graph $Path
    if ($null -eq $page -or $null -eq $page.PSObject.Properties['value'] -or $page.value -isnot [array]) { throw 'ReadFailed' }
    # Incomplete inventories must never establish readiness.
    if ($page.PSObject.Properties['@odata.nextLink'] -and $page.'@odata.nextLink') { throw 'ReadUnavailable' }
    return @($page.value)
}

function Test-MwidPublicHealth {
    param([string]$Hostname)
    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.AllowAutoRedirect = $false
    $client = [Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(15)
    try {
        $response = $client.GetAsync("https://$Hostname/api/general", [Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        try {
            if ([int]$response.StatusCode -ne 200) { return $false }
            $stream = $response.Content.ReadAsStream()
            $reader = [IO.StreamReader]::new($stream)
            $cancellation = [Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(15))
            try {
                $buffer = [char[]]::new(4097)
                $count = $reader.ReadBlockAsync([Memory[char]]::new($buffer), $cancellation.Token).AsTask().GetAwaiter().GetResult()
                return ($count -le 4096 -and (-join $buffer[0..([Math]::Max(0,$count-1))]).Trim() -cin @('Healthy','"Healthy"'))
            } finally { $cancellation.Dispose(); $reader.Dispose() }
        } finally { $response.Dispose() }
    } catch { return $false } finally { $client.Dispose(); $handler.Dispose() }
}

function Test-MwidDns {
    param([string]$Hostname, [string]$DefaultHostname, [string]$VerificationId)
    try {
        $cnames = @(Resolve-DnsName -Name $Hostname -Type CNAME -DnsOnly -ErrorAction Stop)
        $txt = @(Resolve-DnsName -Name "asuid.$Hostname" -Type TXT -DnsOnly -ErrorAction Stop)
        return (@($cnames | Where-Object { $_.NameHost.TrimEnd('.') -eq $DefaultHostname }).Count -gt 0 -and
            @($txt | Where-Object { ($_.Strings -join '') -ceq $VerificationId }).Count -gt 0)
    } catch { return $false }
}

function Get-MwidSetupStatus {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Target)
    $allowed = @('account','accountObjectId','tenantId','subscriptionId','resourceGroup','siteName','backendApplicationId','backendClientId','frontendApplicationId','frontendClientId','backendServicePrincipalId','managedIdentityPrincipalId','customDomains','managedCertificate','authenticationContexts','accessGroups','privilegedCredentials','verifiedIdEnabled')
    foreach ($p in $Target.PSObject.Properties.Name) { if ($p -notin $allowed) { throw 'Unsupported target field.' } }
    foreach ($p in @('backendApplicationId','backendClientId','frontendApplicationId','frontendClientId','backendServicePrincipalId','managedIdentityPrincipalId')) { if (-not $Target.PSObject.Properties[$p]) { $Target | Add-Member -NotePropertyName $p -NotePropertyValue $null } }
    foreach ($p in @('customDomains','authenticationContexts','accessGroups')) { if (-not $Target.PSObject.Properties[$p]) { $Target | Add-Member -NotePropertyName $p -NotePropertyValue @() } }
    foreach ($p in @('managedCertificate','privilegedCredentials','verifiedIdEnabled')) { if (-not $Target.PSObject.Properties[$p]) { $Target | Add-Member -NotePropertyName $p -NotePropertyValue $false }; if ($Target.$p -isnot [bool]) { throw 'Feature selectors must be booleans.' } }
    foreach ($p in @('accountObjectId','tenantId','subscriptionId')) { if ([string]$Target.$p -notmatch '^[a-fA-F0-9-]{36}$' -or -not [guid]::TryParse([string]$Target.$p,[ref]([guid]::Empty))) { throw 'Invalid target identity.' } }
    if ($Target.account -notmatch '^[^\s@]+@[^\s@]+$' -or $Target.resourceGroup -notmatch '^[A-Za-z0-9_-]{1,90}$' -or $Target.siteName -notmatch '^[A-Za-z0-9-]{2,60}$') { throw 'Invalid target scope.' }
    foreach ($p in @('backendApplicationId','backendClientId','frontendApplicationId','frontendClientId','backendServicePrincipalId','managedIdentityPrincipalId')) {
        if ($Target.$p -and ([string]$Target.$p -notmatch '^[a-fA-F0-9-]{36}$' -or -not [guid]::TryParse([string]$Target.$p,[ref]([guid]::Empty)))) { throw 'Invalid object identity.' }
    }
    foreach ($hostName in @($Target.customDomains)) { if ($hostName -notmatch '^(?=.{1,253}$)[a-zA-Z0-9](?:[a-zA-Z0-9-]*\.)+[a-zA-Z]{2,63}$') { throw 'Invalid public hostname.' } }
    foreach ($context in @($Target.authenticationContexts)) { if ($context -notmatch '^c(?:[1-9]|[1-9][0-9])$') { throw 'Invalid authentication context.' } }
    foreach ($group in @($Target.accessGroups)) { if ($group.id -notmatch '^[a-fA-F0-9-]{36}$' -or $group.roleId -notin @('16f5de80-8ee7-46e3-8bfe-7de7af6164ed','9262ab98-6c08-4e32-bae3-4c12d4ce2463','13c4693c-84f1-43b4-85a2-5e51d41753ed','eeacf7de-5c05-4e21-a2be-a4d8e3435237')) { throw 'Invalid access group binding.' } }
    try { Get-MwidCachedContext $Target } catch { throw 'Selected account, tenant or subscription is unavailable or mismatched. No setup reads were performed.' }
    $results = [Collections.Generic.List[object]]::new()
    function Add-Gate($Name, $Status, $Code, $Action) { $results.Add([pscustomobject]@{ gate=$Name; status=$Status; code=$Code; action=$Action }) }
    function Inspect-Gate($Name, [scriptblock]$Probe, $Action) {
        try { if (& $Probe) { Add-Gate $Name ready observed 'None.' } else { Add-Gate $Name pending incomplete $Action } }
        catch { if ($_.Exception.Message -eq 'ReadUnavailable') { Add-Gate $Name pending readUnavailable 'Provide an existing authorized read context, or retry the bounded read; do not rerun provisioning to inspect status.' } else { Add-Gate $Name failed invalidEvidence 'Inspect the selected target and response shape; readiness was not established.' } }
    }
    $sitePath = "/subscriptions/$($Target.subscriptionId)/resourceGroups/$($Target.resourceGroup)/providers/Microsoft.Web/sites/$($Target.siteName)"
    $site = $null
    if (-not $Target.managedIdentityPrincipalId) { Add-Gate hosting pending missingBinding 'Supply the reviewed App Service managed identity object ID before establishing ownership.' }
    else {
    try {
        $site = Read-MwidApi $Target arm ($sitePath + '?api-version=2023-12-01')
        if ($site -and ($site.id -ne $sitePath -or $site.name -ne $Target.siteName -or $site.identity.tenantId -ne $Target.tenantId -or $site.identity.principalId -ne $Target.managedIdentityPrincipalId)) { throw 'ReadBindingFailed' }
        if ($site -and $site.properties.state -eq 'Running') { Add-Gate hosting ready observed 'None.' } else { Add-Gate hosting pending incomplete 'Confirm the selected App Service exists and is running.' }
    } catch { $site=$null; if ($_.Exception.Message -eq 'ReadUnavailable') { Add-Gate hosting pending readUnavailable 'Provide read access to the exact selected App Service; no application settings or keys are fetched.' } else { Add-Gate hosting failed invalidEvidence 'The App Service response did not establish exact target ownership.' } }
    }
    foreach ($kind in @('backend','frontend')) {
        $oid = $Target."${kind}ApplicationId"; $clientId = $Target."${kind}ClientId"
        if (-not $oid -or -not $clientId) { Add-Gate "${kind}Application" pending missingBinding 'Supply the reviewed application object ID and client ID.'; continue }
        Inspect-Gate "${kind}Application" {
            $app = Read-MwidApi $Target graph "/applications/$oid`?`$select=id,appId,web,spa"
            if (-not $app) { return $false }
            if ($app.id -ne $oid -or $app.appId -ne $clientId) { throw 'ReadBindingFailed' }
            if ($kind -eq 'frontend') {
                if (-not $site) { return $false }
                $required = @($site.properties.defaultHostName) + @($Target.customDomains)
                $uris = @($app.spa.redirectUris) + @($app.web.redirectUris)
                foreach ($h in $required) { if ("https://$h/" -notin $uris -and "https://$h" -notin $uris) { return $false } }
            }
            return $true
        } 'Confirm the exact application and frontend HTTPS redirects; changing redirects requires separate authorization.'
    }
    Inspect-Gate frontendConsent {
        if (-not $Target.frontendClientId -or -not $Target.backendServicePrincipalId) { return $false }
        $front = @(Read-MwidCollection $Target "/servicePrincipals?`$filter=appId%20eq%20'$($Target.frontendClientId)'&`$select=id,appId")
        $backend = Read-MwidApi $Target graph "/servicePrincipals/$($Target.backendServicePrincipalId)?`$select=id,appId"
        $graph = @(Read-MwidCollection $Target "/servicePrincipals?`$filter=appId%20eq%20'00000003-0000-0000-c000-000000000000'&`$select=id,appId")
        if ($front.Count -ne 1 -or $front[0].appId -ne $Target.frontendClientId -or -not $backend -or $backend.id -ne $Target.backendServicePrincipalId -or $backend.appId -ne $Target.backendClientId -or $graph.Count -ne 1 -or $graph[0].appId -ne '00000003-0000-0000-c000-000000000000') { throw 'ReadBindingFailed' }
        $grants = @(Read-MwidCollection $Target "/oauth2PermissionGrants?`$filter=clientId%20eq%20'$($front[0].id)'")
        foreach ($resource in @(@{id=$backend.id;scopes=@('openid','Access')},@{id=$graph[0].id;scopes=@('User.Read')})) {
            $match = @($grants | Where-Object {
                $grant = $_
                $grant.clientId -eq $front[0].id -and $grant.resourceId -eq $resource.id -and $grant.consentType -eq 'AllPrincipals' -and
                    @($resource.scopes | Where-Object { $_ -cnotin $grant.scope.Split(' ') }).Count -eq 0
            })
            if ($match.Count -eq 0) { return $false }
        }; return $true
    } 'Review frontend delegated consent to the exact backend and Microsoft Graph separately; this command does not request consent.'
    if (@($Target.authenticationContexts | Select-Object -Unique).Count -ne 3) { Add-Gate authenticationContexts pending missingBinding 'Supply all three reviewed journey context IDs; defaults are not approval.' }
    foreach ($context in @($Target.authenticationContexts)) {
        Inspect-Gate "context.$context" {
            $dto = Read-MwidApi $Target graph "/identity/conditionalAccess/authenticationContextClassReferences/$context"
            if ($dto -and $dto.id -ne $context) { throw 'ReadBindingFailed' }
            return ($dto -and $dto.isAvailable -eq $true)
        } 'Review and publish the intended authentication context separately.'
        Inspect-Gate "policy.$context" {
            $policies = @(Read-MwidCollection $Target '/identity/conditionalAccess/policies?$select=id,state,conditions,grantControls')
            # Enabled linkage is observable; policy suitability still requires administrator judgment.
            return @($policies | Where-Object { $_.state -eq 'enabled' -and $context -in @($_.conditions.applications.includeAuthenticationContextClassReferences) }).Count -gt 0
        } 'Review an enabled policy linked to this context. This check does not certify policy effectiveness.'
    }
    if (-not $Target.managedIdentityPrincipalId) { Add-Gate runtimePermissions pending missingBinding 'Supply the selected App Service managed identity object ID.' }
    else {
        Inspect-Gate runtimePermissions {
            $sp = Read-MwidApi $Target graph "/servicePrincipals/$($Target.managedIdentityPrincipalId)?`$select=id,appRoles"
            if (-not $sp) { return $false }; if ($sp.id -ne $Target.managedIdentityPrincipalId) { throw 'ReadBindingFailed' }
            $assignments = @(Read-MwidCollection $Target "/servicePrincipals/$($Target.managedIdentityPrincipalId)/appRoleAssignments?`$select=principalId,resourceId,appRoleId")
            foreach ($resourceApp in @('00000003-0000-0000-c000-000000000000','3db474b9-6a0c-4840-96ac-1fceb342124f')) {
                $resources = @(Read-MwidCollection $Target "/servicePrincipals?`$filter=appId%20eq%20'$resourceApp'&`$select=id,appId,appRoles")
                if ($resources.Count -ne 1 -or $resources[0].appId -ne $resourceApp) { throw 'ReadBindingFailed' }
                $roles = if ($resourceApp -eq '00000003-0000-0000-c000-000000000000') { @($resources[0].appRoles | Where-Object value -in @('IdentityRiskyUser.ReadWrite.All','CustomSecAttributeAssignment.ReadWrite.All')) } else { @($resources[0].appRoles | Where-Object id -eq '949ebb93-18f8-41b4-b677-c2bfea940027') }
                $expectedCount = if ($resourceApp -eq '00000003-0000-0000-c000-000000000000') { 2 } else { 1 }
                if ($roles.Count -ne $expectedCount) { return $false }
                foreach ($role in $roles) { if (@($assignments | Where-Object { $_.principalId -eq $Target.managedIdentityPrincipalId -and $_.resourceId -eq $resources[0].id -and $_.appRoleId -eq $role.id }).Count -eq 0) { return $false } }
            }; return $true
        } 'Review the specific runtime application-role grants separately; this command grants nothing.'
        Inspect-Gate credentialRole {
            $template = if ($Target.privilegedCredentials) { '7be44c8a-adaf-4e2a-84d6-ab2649e08a13' } else { 'c4e39bd9-1100-46d3-8c65-fb160da0071f' }
            $defs = @(Read-MwidCollection $Target "/roleManagement/directory/roleDefinitions?`$filter=templateId%20eq%20'$template'&`$select=id,templateId")
            if ($defs.Count -ne 1 -or $defs[0].templateId -ne $template) { return $false }
            $assignments = @(Read-MwidCollection $Target "/roleManagement/directory/roleAssignments?`$filter=principalId%20eq%20'$($Target.managedIdentityPrincipalId)'&`$select=principalId,roleDefinitionId,directoryScopeId")
            return @($assignments | Where-Object { $_.principalId -eq $Target.managedIdentityPrincipalId -and $_.roleDefinitionId -eq $defs[0].id -and $_.directoryScopeId -eq '/' }).Count -gt 0
        } 'Review the selected authentication-administrator role scope separately. No credential operation is exercised.'
    }
    foreach ($roleId in @('16f5de80-8ee7-46e3-8bfe-7de7af6164ed','9262ab98-6c08-4e32-bae3-4c12d4ce2463','13c4693c-84f1-43b4-85a2-5e51d41753ed','eeacf7de-5c05-4e21-a2be-a4d8e3435237')) {
        if ($roleId -notin @($Target.accessGroups | ForEach-Object roleId)) {
            if ($roleId -eq 'eeacf7de-5c05-4e21-a2be-a4d8e3435237' -and -not $Target.verifiedIdEnabled) { Add-Gate "group.$roleId" skipped disabled 'Optional Verified ID journey not selected.' }
            else { Add-Gate "group.$roleId" pending missingBinding 'Supply the reviewed group object ID for this journey; intentionally omitted groups do not establish journey readiness.' }
        }
    }
    foreach ($group in @($Target.accessGroups)) {
        Inspect-Gate "group.$($group.roleId)" {
            if (-not $Target.backendServicePrincipalId) { return $false }
            $sp = Read-MwidApi $Target graph "/servicePrincipals/$($Target.backendServicePrincipalId)?`$select=id,appId"
            if (-not $sp -or $sp.id -ne $Target.backendServicePrincipalId -or $sp.appId -ne $Target.backendClientId) { throw 'ReadBindingFailed' }
            $dto = Read-MwidApi $Target graph "/groups/$($group.id)?`$select=id"
            if (-not $dto) { return $false }; if ($dto.id -ne $group.id) { throw 'ReadBindingFailed' }
            $assignments = @(Read-MwidCollection $Target "/groups/$($group.id)/appRoleAssignments?`$select=principalId,resourceId,appRoleId")
            return @($assignments | Where-Object { $_.principalId -eq $group.id -and $_.resourceId -eq $Target.backendServicePrincipalId -and $_.appRoleId -eq $group.roleId }).Count -gt 0
        } 'Review the exact group-to-backend-role assignment; group membership and user journeys are not exercised.'
    }
    if (@($Target.customDomains).Count -eq 0) { Add-Gate customDomain skipped notConfigured 'No custom domain selected.' }
    foreach ($h in @($Target.customDomains)) {
        Inspect-Gate "dns.$h" { if (-not $site) { return $false }; Test-MwidDns $h $site.properties.defaultHostName $site.properties.customDomainVerificationId } 'Complete the selected hostname CNAME and asuid TXT records separately; this command writes no DNS.'
        Inspect-Gate "binding.$h" {
            $binding = Read-MwidApi $Target arm "$sitePath/hostNameBindings/$h`?api-version=2023-12-01"
            if (-not $binding) { return $false }; if ($binding.id -ne "$sitePath/hostNameBindings/$h") { throw 'ReadBindingFailed' }
            return ($binding.properties.sslState -eq 'SniEnabled' -and -not [string]::IsNullOrWhiteSpace($binding.properties.thumbprint))
        } 'Complete the selected hostname HTTPS binding separately.'
        if ($Target.managedCertificate) {
            Inspect-Gate "certificate.$h" {
                $certs = Read-MwidApi $Target arm "/subscriptions/$($Target.subscriptionId)/resourceGroups/$($Target.resourceGroup)/providers/Microsoft.Web/certificates?api-version=2023-12-01"
                if ($certs.PSObject.Properties['nextLink'] -and $certs.nextLink) { throw 'ReadUnavailable' }
                $bound = Read-MwidApi $Target arm "$sitePath/hostNameBindings/$h`?api-version=2023-12-01"
                if (-not $bound) { return $false }; if ($bound.id -ne "$sitePath/hostNameBindings/$h") { throw 'ReadBindingFailed' }
                return @($certs.value | Where-Object { $_.id.StartsWith("/subscriptions/$($Target.subscriptionId)/resourceGroups/$($Target.resourceGroup)/providers/Microsoft.Web/certificates/",[StringComparison]::OrdinalIgnoreCase) -and $_.properties.canonicalName -eq $h -and $_.properties.thumbprint -and $_.properties.thumbprint -eq $bound.properties.thumbprint -and [DateTimeOffset]::Parse($_.properties.expirationDate) -gt [DateTimeOffset]::UtcNow }).Count -gt 0
            } 'Wait for managed certificate issuance or review the selected certificate; no issuance is requested.'
        } else { Add-Gate "certificate.$h" skipped externallyManaged 'Managed issuance not selected; HTTPS validation still applies.' }
        Inspect-Gate "https.$h" { if (-not $site -or $h -notin @($site.properties.hostNames) -or -not (Test-MwidDns $h $site.properties.defaultHostName $site.properties.customDomainVerificationId)) { return $false }; Test-MwidPublicHealth $h } 'Validate target-bound DNS, trusted TLS and the public health endpoint after propagation; redirects are not followed.'
    }
    if ($Target.verifiedIdEnabled) { Add-Gate verifiedId pending operatorVerification 'Verify issuer configuration, signing-secret availability and security attributes through an authorized operator workflow. This read-only command never fetches secret values or issues credentials.' }
    else { Add-Gate verifiedId skipped disabled 'Optional Verified ID not selected.' }
    Add-Gate userJourneys pending operatorVerification 'An intended test user must validate sign-in, TAP, password reset and risk dismissal separately; no credentials are generated.'
    Add-Gate telemetry pending operatorVerification 'Confirm application telemetry separately; hosting metadata does not prove ingestion.'
    return [pscustomobject]@{ schemaVersion='1.0'; observedAt=[DateTimeOffset]::UtcNow.ToString('o'); tenantId=$Target.tenantId; subscriptionId=$Target.subscriptionId; resourceId=$sitePath; readOnly=$true; gates=@($results.ToArray()) }
}
Export-ModuleMember -Function Get-MwidSetupStatus
