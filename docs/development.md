# Development

Administrators should use the default `releaseZip` mode and do not need local build tooling.

Contributors using `sourceBuild` need .NET SDK 8, Node.js, and npm. That mode builds `src/MyWorkID.Client` with npm and `src/MyWorkID.Server` with `dotnet publish`, then stages the combined output for `azd deploy`.

Keep contributor tooling, package changes, and release validation separate from the administrator deployment path. Validate the selected upstream version and generated package before publication.

Run `./scripts/Test-SetupStatus.ps1` with PowerShell 7.6+, then the existing
`dotnet restore`, `dotnet build --configuration Release --no-restore` and
`dotnet test --logger "trx;logfilename=testResults.trx"` checks. Validate client
build changes with `npm ci` and `npm run build` from `src/MyWorkID.Client`.
Status fixtures perform no authentication, Azure queries or provisioning writes.
