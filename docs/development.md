# Development

Administrators should use the default `releaseZip` mode and do not need local build tooling.

Contributors using `sourceBuild` need .NET SDK 8, Node.js, and npm. That mode builds `src/MyWorkID.Client` with npm and `src/MyWorkID.Server` with `dotnet publish`, then stages the combined output for `azd deploy`.

Keep contributor tooling, package changes, and release validation separate from the administrator deployment path. Validate the selected upstream version and generated package before publication.
