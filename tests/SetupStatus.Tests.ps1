#Requires -Version 7.6
BeforeDiscovery { Import-Module "$PSScriptRoot/../scripts/MyWorkID.Status.psm1" -Force }
Describe 'Read-only setup status' {
    InModuleScope MyWorkID.Status {
        BeforeAll {
            function New-TestTarget {
                [pscustomobject]@{
                    account='reader@example.invalid'; accountObjectId='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'; tenantId='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'; subscriptionId='cccccccc-cccc-cccc-cccc-cccccccccccc'
                    resourceGroup='fixture-rg'; siteName='fixture-site'; backendApplicationId='11111111-1111-1111-1111-111111111111'; backendClientId='22222222-2222-2222-2222-222222222222'
                    frontendApplicationId='33333333-3333-3333-3333-333333333333'; frontendClientId='44444444-4444-4444-4444-444444444444'; backendServicePrincipalId='55555555-5555-5555-5555-555555555555'; managedIdentityPrincipalId='66666666-6666-6666-6666-666666666666'
                    customDomains=@('login.example.invalid'); managedCertificate=$true; authenticationContexts=@('c50','c51','c52'); privilegedCredentials=$false; verifiedIdEnabled=$true
                    accessGroups=@(
                        [pscustomobject]@{id='77777777-7777-7777-7777-777777777777';roleId='16f5de80-8ee7-46e3-8bfe-7de7af6164ed'},
                        [pscustomobject]@{id='88888888-8888-8888-8888-888888888888';roleId='9262ab98-6c08-4e32-bae3-4c12d4ce2463'},
                        [pscustomobject]@{id='99999999-9999-9999-9999-999999999999';roleId='13c4693c-84f1-43b4-85a2-5e51d41753ed'},
                        [pscustomobject]@{id='aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';roleId='eeacf7de-5c05-4e21-a2be-a4d8e3435237'})
                }
            }
            function New-WireDto([string]$Uri) {
                $t=$script:target
                if ($Uri -like 'https://management.azure.com*') {
                    if ($Uri -match '/hostNameBindings/') { return @{id="$script:siteId/hostNameBindings/login.example.invalid";properties=@{sslState='SniEnabled';thumbprint='fixture-thumbprint'}} }
                    if ($Uri -match '/certificates') { return @{value=@(@{id="/subscriptions/$($t.subscriptionId)/resourceGroups/fixture-rg/providers/Microsoft.Web/certificates/fixture-cert";properties=@{canonicalName='login.example.invalid';thumbprint='fixture-thumbprint';expirationDate='2099-01-02T00:00:00Z'}})} }
                    return @{id=$script:siteId;name=$t.siteName;identity=@{tenantId=$t.tenantId;principalId=$t.managedIdentityPrincipalId};properties=@{state='Running';defaultHostName='fixture-site.azurewebsites.net';hostNames=@('fixture-site.azurewebsites.net','login.example.invalid');customDomainVerificationId='fixture-verification'}}
                }
                if ($Uri -match '/applications/([^?]+)') {
                    $id=$Matches[1]; $client=if($id -eq $t.backendApplicationId){$t.backendClientId}else{$t.frontendClientId}
                    return @{id=$id;appId=$client;spa=@{redirectUris=@('https://fixture-site.azurewebsites.net/','https://login.example.invalid/')};web=@{redirectUris=@()}}
                }
                if ($Uri -match 'authenticationContextClassReferences/(c\d+)') { return @{id=$Matches[1];isAvailable=$true} }
                if ($Uri -match '/conditionalAccess/policies') { return @{value=@(@{id='fixture-policy';state='enabled';conditions=@{applications=@{includeAuthenticationContextClassReferences=@('c50','c51','c52')}};grantControls=@{builtInControls=@('mfa')}})} }
                if ($Uri -match '/roleDefinitions') { return @{value=@(@{id='fixture-role';templateId=if($t.privilegedCredentials){'7be44c8a-adaf-4e2a-84d6-ab2649e08a13'}else{'c4e39bd9-1100-46d3-8c65-fb160da0071f'}})} }
                if ($Uri -match '/roleAssignments') { return @{value=@(@{principalId=$t.managedIdentityPrincipalId;roleDefinitionId='fixture-role';directoryScopeId='/'})} }
                if ($Uri -match '/oauth2PermissionGrants') { return @{value=@(@{clientId='fixture-front-sp';resourceId=$t.backendServicePrincipalId;consentType='AllPrincipals';scope='openid Access'},@{clientId='fixture-front-sp';resourceId='fixture-graph-sp';consentType='AllPrincipals';scope='User.Read'})} }
                if ($Uri -match '/groups/([^/]+)/appRoleAssignments') { $group=$t.accessGroups|Where-Object id -eq $Matches[1]; return @{value=@(@{principalId=$group.id;resourceId=$t.backendServicePrincipalId;appRoleId=$group.roleId})} }
                if ($Uri -match '/groups/([^?]+)') { return @{id=$Matches[1]} }
                if ($Uri -match '/servicePrincipals/.*/appRoleAssignments') { return @{value=@(@{principalId=$t.managedIdentityPrincipalId;resourceId='fixture-graph-sp';appRoleId='fixture-risk'},@{principalId=$t.managedIdentityPrincipalId;resourceId='fixture-graph-sp';appRoleId='fixture-attributes'},@{principalId=$t.managedIdentityPrincipalId;resourceId='fixture-vc-sp';appRoleId='949ebb93-18f8-41b4-b677-c2bfea940027'})} }
                if ($Uri -match '/servicePrincipals\?') {
                    if ($Uri -match '00000003-0000-0000-c000-000000000000') { return @{value=@(@{id='fixture-graph-sp';appId='00000003-0000-0000-c000-000000000000';appRoles=@(@{id='fixture-risk';value='IdentityRiskyUser.ReadWrite.All'},@{id='fixture-attributes';value='CustomSecAttributeAssignment.ReadWrite.All'})})} }
                    if ($Uri -match '3db474b9') { return @{value=@(@{id='fixture-vc-sp';appId='3db474b9-6a0c-4840-96ac-1fceb342124f';appRoles=@(@{id='949ebb93-18f8-41b4-b677-c2bfea940027';value='VerifiableCredential.Create.All'})})} }
                    return @{value=@(@{id='fixture-front-sp';appId=$t.frontendClientId})}
                }
                if ($Uri -match '/servicePrincipals/([^?]+)') { return @{id=$Matches[1];appId=$t.backendClientId;appRoles=@()} }
                throw 'Unexpected fixture request.'
            }
        }
        BeforeEach {
            $script:target=New-TestTarget
            $script:siteId="/subscriptions/$($script:target.subscriptionId)/resourceGroups/fixture-rg/providers/Microsoft.Web/sites/fixture-site"
            $script:mutate=$null
            Mock Get-MwidCachedContext {}
            Mock Get-MwidReadToken { 'synthetic-token-never-native' }
            Mock Test-MwidDns { $true }
            Mock Test-MwidPublicHealth { $true }
            Mock Invoke-WebRequest {
                param($Uri,$Method,$Headers,$MaximumRedirection)
                if ($Method -ne 'Get' -or $MaximumRedirection -ne 0) { throw 'Unsafe request.' }
                $dto=New-WireDto $Uri
                if ($script:mutate) { $dto=& $script:mutate $Uri $dto }
                [pscustomobject]@{Content=($dto|ConvertTo-Json -Depth 16 -Compress)}
            }
            Mock az { throw 'Unexpected native CLI invocation.' }
        }
        It 'uses actual wire JSON and establishes fresh bounded readiness for every observable gate' {
            $r=Get-MwidSetupStatus $script:target
            @($r.gates|Where-Object status -ne ready|Where-Object gate -notin @('verifiedId','userJourneys','telemetry')).Count | Should -Be 0
            @($r.gates|Where-Object status -eq ready).Count | Should -BeGreaterThan 10
            $r.readOnly | Should -BeTrue
            $r.resourceId | Should -Be $script:siteId
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter { $Uri -eq "https://management.azure.com$script:siteId`?api-version=2023-12-01" }
            Should -Invoke az -Times 0
        }
        It 'stops before all setup reads on account mismatch' {
            Mock Get-MwidCachedContext { throw 'SECRET-SENTINEL' }
            {Get-MwidSetupStatus $script:target} | Should -Throw '*No setup reads*'
            Should -Invoke Invoke-WebRequest -Times 0
        }
        It 'refuses foreign App Service identity rather than accepting running status' {
            $script:mutate={param($u,$d) if($d.ContainsKey('identity')){$d.identity.tenantId='foreign'}; $d}
            $r=Get-MwidSetupStatus $script:target
            ($r.gates|Where-Object gate -eq hosting).status | Should -Be failed
            Should -Invoke Test-MwidPublicHealth -Times 0
        }
        It 'refuses mismatched application identity' {
            $script:mutate={param($u,$d) if($u -match '/applications/'){$d.appId='foreign'}; $d}
            $r=Get-MwidSetupStatus $script:target
            ($r.gates|Where-Object gate -eq backendApplication).status | Should -Be failed
        }
        It 'does not infer grant readiness from the wrong principal' {
            $script:mutate={param($u,$d) if($u -match '/appRoleAssignments'){$d.value=@()}; $d}
            $r=Get-MwidSetupStatus $script:target
            ($r.gates|Where-Object gate -eq runtimePermissions).status | Should -Be pending
            @($r.gates|Where-Object gate -like 'group.*'|Where-Object status -eq pending).Count | Should -Be 4
        }
        It 'keeps a disabled Conditional Access linkage pending' {
            $script:mutate={param($u,$d) if($u -match '/conditionalAccess/policies'){$d.value[0].state='disabled'}; $d}
            $r=Get-MwidSetupStatus $script:target
            @($r.gates|Where-Object gate -like 'policy.*'|Where-Object status -eq pending).Count | Should -Be 3
        }
        It 'does not claim readiness from incomplete paginated inventories' {
            $script:mutate={param($u,$d) if($d.ContainsKey('value')){$d['@odata.nextLink']='https://foreign.invalid/SECRET-SENTINEL'}; $d}
            $r=Get-MwidSetupStatus $script:target
            ($r.gates|Where-Object gate -eq runtimePermissions).status | Should -Be pending
            ($r|ConvertTo-Json -Depth 16) | Should -Not -Match 'SECRET-SENTINEL|foreign.invalid'
        }
        It 'preserves pending DNS and HTTPS without provisioning reruns' {
            Mock Test-MwidDns {$false}; Mock Test-MwidPublicHealth {$false}
            $r=Get-MwidSetupStatus $script:target
            ($r.gates|Where-Object gate -like 'dns.*').status | Should -Be pending
            ($r.gates|Where-Object gate -like 'https.*').status | Should -Be pending
            Should -Invoke Test-MwidPublicHealth -Times 0
        }
        It 'skips only explicitly disabled optional components' {
            $script:target.customDomains=@();$script:target.verifiedIdEnabled=$false
            $r=Get-MwidSetupStatus $script:target
            ($r.gates|Where-Object gate -eq customDomain).status | Should -Be skipped
            ($r.gates|Where-Object gate -eq verifiedId).status | Should -Be skipped
        }
        It 'keeps external certificates distinct from actual HTTPS health' {
            $script:target.managedCertificate=$false
            $r=Get-MwidSetupStatus $script:target
            ($r.gates|Where-Object gate -like 'certificate.*').status | Should -Be skipped
            ($r.gates|Where-Object gate -like 'https.*').status | Should -Be ready
        }
        It 'emits only fixed errors and never arbitrary response bodies or tokens' {
            Mock Invoke-WebRequest {throw 'SECRET-SENTINEL token=synthetic-token-never-native https://secret.invalid'}
            $r=Get-MwidSetupStatus $script:target
            ($r|ConvertTo-Json -Depth 16) | Should -Not -Match 'SECRET-SENTINEL|synthetic-token|secret.invalid'
            ($r.gates|Where-Object gate -eq backendApplication).status | Should -Be pending
        }
        It 'marks malformed wire JSON as failed rather than readiness or unavailable' {
            Mock Invoke-WebRequest {[pscustomobject]@{Content='{SECRET-SENTINEL'}}
            $r=Get-MwidSetupStatus $script:target
            ($r.gates|Where-Object gate -eq backendApplication).status | Should -Be failed
            ($r|ConvertTo-Json -Depth 16) | Should -Not -Match 'SECRET-SENTINEL'
        }
        It 'rejects unknown fields and malformed identities before requests' {
            $script:target|Add-Member secret 'SECRET-SENTINEL'
            {Get-MwidSetupStatus $script:target}|Should -Throw 'Unsupported target field.'
            Should -Invoke Invoke-WebRequest -Times 0
        }
        It 'rejects URL and path injection before requests' {
            $script:target.siteName='../foreign?token=SECRET-SENTINEL'
            {Get-MwidSetupStatus $script:target}|Should -Throw 'Invalid target scope.'
            Should -Invoke Invoke-WebRequest -Times 0
        }
        It 'guards cross-subscription native API paths before token access' {
            {Read-MwidApi $script:target arm '/subscriptions/foreign/resourceGroups/fixture-rg/providers/Microsoft.Web/sites/fixture-site'} | Should -Throw 'ReadBindingFailed'
            Should -Invoke Get-MwidReadToken -Times 0
        }
        It 'has no hook imports or writes in any native request' {
            $source=Get-Content "$PSScriptRoot/../scripts/MyWorkID.Status.psm1" -Raw
            $source | Should -Not -Match 'Ensure-|Set-AzdEnvironmentValue|MyWorkID.Hooks|auth login|azd auth|listKeys|/secrets|/temporaryAccessPassMethods'
            Get-MwidSetupStatus $script:target | Out-Null
            Should -Invoke Invoke-WebRequest -Times 0 -ParameterFilter {$Method -ne 'Get'}
        }
        It 'does not accept absent applications as ready' {
            Mock Read-MwidApi {$null} -ParameterFilter {$Service -eq 'graph' -and $Path -like '/applications/*'}
            $r=Get-MwidSetupStatus $script:target
            ($r.gates|Where-Object gate -eq backendApplication).status|Should -Be pending
        }
        It 'refuses certificate readiness when the issued certificate is not the bound certificate' {
            $script:mutate={param($u,$d) if($u -match '/certificates'){$d.value[0].properties.thumbprint='wrong-thumbprint'}; $d}
            $r=Get-MwidSetupStatus $script:target
            ($r.gates|Where-Object gate -like 'certificate.*').status|Should -Be pending
        }
        It 'does not treat an expired certificate as ready' {
            $script:mutate={param($u,$d) if($u -match '/certificates'){$d.value[0].properties.expirationDate='2000-01-02T00:00:00Z'}; $d}
            $r=Get-MwidSetupStatus $script:target
            ($r.gates|Where-Object gate -like 'certificate.*').status|Should -Be pending
        }
        It 'does not accept directory roles scoped to a different object' {
            $script:mutate={param($u,$d) if($u -match '/roleAssignments'){$d.value[0].directoryScopeId='/foreign'}; $d}
            $r=Get-MwidSetupStatus $script:target
            ($r.gates|Where-Object gate -eq credentialRole).status|Should -Be pending
        }
        It 'does not combine user-specific consent with tenant-wide consent' {
            $script:mutate={param($u,$d) if($u -match '/oauth2PermissionGrants'){$d.value[0].consentType='Principal'}; $d}
            $r=Get-MwidSetupStatus $script:target
            ($r.gates|Where-Object gate -eq frontendConsent).status|Should -Be pending
        }
        It 'never serializes arbitrary allowed-provider fields' {
            $script:mutate={param($u,$d) $d['password']='SECRET-SENTINEL';$d['rawError']='SECRET-SENTINEL';$d}
            $r=Get-MwidSetupStatus $script:target
            ($r|ConvertTo-Json -Depth 16)|Should -Not -Match 'SECRET-SENTINEL|"password"\s*:|"rawError"\s*:'
        }
        It 'preserves dates as strings at the actual native wire boundary' {
            $dto=Read-MwidApi $script:target arm "/subscriptions/$($script:target.subscriptionId)/resourceGroups/fixture-rg/providers/Microsoft.Web/certificates?api-version=2023-12-01"
            $dto.value[0].properties.expirationDate|Should -BeOfType ([string])
        }
        It 'leaves omitted object bindings actionable pending rather than failing or inventing readiness' {
            $script:target.managedIdentityPrincipalId=$null;$script:target.backendApplicationId=$null
            $r=Get-MwidSetupStatus $script:target
            ($r.gates|Where-Object gate -eq hosting).code|Should -Be missingBinding
            ($r.gates|Where-Object gate -eq backendApplication).status|Should -Be pending
            Should -Invoke Test-MwidPublicHealth -Times 0
        }
        It 'checks the explicitly selected privileged authentication role without assigning it' {
            $script:target.privilegedCredentials=$true
            $r=Get-MwidSetupStatus $script:target
            ($r.gates|Where-Object gate -eq credentialRole).status|Should -Be ready
            Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {$Uri -like '*roleDefinitions*7be44c8a-adaf-4e2a-84d6-ab2649e08a13*'}
        }
        It 'retains every omitted journey binding as an individual pending gate' {
            $script:target.accessGroups=@()
            $r=Get-MwidSetupStatus $script:target
            @($r.gates|Where-Object gate -like 'group.*'|Where-Object code -eq missingBinding).Count|Should -Be 4
        }
    }
}

Describe 'Native account and token selection' {
    InModuleScope MyWorkID.Status {
        BeforeEach {
            $script:target=[pscustomobject]@{subscriptionId='cccccccc-cccc-cccc-cccc-cccccccccccc';tenantId='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';account='reader@example.invalid';accountObjectId='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'}
            $script:claims=@{tid=$script:target.tenantId;oid=$script:target.accountObjectId;aud='https://graph.microsoft.com';exp=([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+600);scp='Application.Read.All'}
            $script:account=@{id=$script:target.subscriptionId;tenantId=$script:target.tenantId;user=@{name=$script:target.account;type='user'}}
            Mock az {
                $global:LASTEXITCODE=0
                if ($args[1] -eq 'show') { return ($script:account|ConvertTo-Json -Depth 5 -Compress) }
                $bytes=[Text.Encoding]::UTF8.GetBytes(($script:claims|ConvertTo-Json -Compress))
                $part=[Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+','-').Replace('/','_')
                return (@{accessToken="fixture.$part.signature"}|ConvertTo-Json -Compress)
            }
            Mock Invoke-WebRequest {throw 'Must not issue native HTTP during account/token tests.'}
        }
        It 'accepts only the selected cached user context' { {Get-MwidCachedContext $script:target}|Should -Not -Throw }
        It 'rejects a different active subscription' { $script:account.id='foreign';{Get-MwidCachedContext $script:target}|Should -Throw 'AccountMismatch' }
        It 'rejects a different active user' { $script:account.user.name='foreign@example.invalid';{Get-MwidCachedContext $script:target}|Should -Throw 'AccountMismatch' }
        It 'rejects a non-user context' { $script:account.user.type='servicePrincipal';{Get-MwidCachedContext $script:target}|Should -Throw 'AccountMismatch' }
        It 'accepts a tenant and object-bound unexpired delegated audience token' { (Get-MwidReadToken $script:target graph)|Should -Match '^fixture\.' }
        It 'rejects wrong tenant tokens before any HTTP' { $script:claims.tid='foreign';{Get-MwidReadToken $script:target graph}|Should -Throw 'ReadUnavailable';Should -Invoke Invoke-WebRequest -Times 0 }
        It 'rejects wrong account object tokens' { $script:claims.oid='foreign';{Get-MwidReadToken $script:target graph}|Should -Throw 'ReadUnavailable' }
        It 'rejects ARM tokens for Graph reads' { $script:claims.aud='https://management.azure.com/';{Get-MwidReadToken $script:target graph}|Should -Throw 'ReadUnavailable' }
        It 'rejects expired tokens' { $script:claims.exp=1;{Get-MwidReadToken $script:target graph}|Should -Throw 'ReadUnavailable' }
        It 'rejects application tokens' { $script:claims.Remove('scp');{Get-MwidReadToken $script:target graph}|Should -Throw 'ReadUnavailable' }
    }
}

Describe 'Command-line input boundary' {
    It 'redacts malformed target contents before account or API access' {
        $path=Join-Path $TestDrive 'malformed-target.json'
        '{"token":"SECRET-SENTINEL"'|Set-Content -LiteralPath $path
        $output=& pwsh -NoProfile -File "$PSScriptRoot/../scripts/Get-SetupStatus.ps1" -TargetPath $path 2>&1
        $LASTEXITCODE|Should -Not -Be 0
        ($output|Out-String)|Should -Match 'Setup status could not be produced'
        ($output|Out-String)|Should -Not -Match 'SECRET-SENTINEL'
    }
}
