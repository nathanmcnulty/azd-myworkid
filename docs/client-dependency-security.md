# Client build dependency mitigation

MyWorkID's locked client tree contains one `braces` 3.0.3 package, reached by
`micromatch` through build/lint dependencies. On 2026-10-16 the npm registry still
lists 3.0.3 as latest, and [GHSA-vfj7-8cjw-p6xm](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm)
lists no patched release. MWID-007 remains blocked on upstream remediation.

`npm ci` now runs the local `tools/dependency-patches/apply.mjs` through
`postinstall`. It verifies the locked copy's location/version, the installed
version, the exact upstream SHA-256 values and the resulting patched values.
Unexpected bytes, extra locked copies and changed helper bytes fail installation
so dependency changes require review. The patch bounds parse nesting to 128 and
checks AST depth, cycles and a 20,000-node limit before recursive walkers run.
It intentionally rejects patterns beyond these limits.

The patch and helper are adapted from the independently reviewed website
[mitigation at revision 90bd8a2a946828066490b675d35aee428d623a90](https://github.com/nathanmcnulty/azd-website/tree/90bd8a2a946828066490b675d35aee428d623a90/tools/dependency-patches).
The helper and four upstream transformations are unchanged. MyWorkID adds a
consumer-specific layout/version guard. All files are vendored locally; installs
have no runtime dependency on the website or `azd-reference` repository.

From `src/MyWorkID.Client`, run:

```sh
npm ci --no-fund --audit=false
npm run test:dependency-patches
npm run build
npm run lint
npm audit --json
```

The regression checks cover ordinary nested patterns/ASTs, excessive parse depth,
oversized/deep/cyclic ASTs, idempotence, helper/source drift and unreviewed package
layouts/versions. Build, development and lint commands run these checks before
using the tools. If scripts were skipped during installation, the checks fail
until a normal install applies the mitigation. CI performs a clean Node 26
installation, client production build and lint, including these checks. To make
the existing lint command pass, this change removes one unused lint directive
and moves the unchanged theme context into its own module so the provider exports
only its React component. Theme state, defaults and storage behavior are preserved.

Local validation on PowerShell 7.6.6/Node 26.7.0/npm 11.19.0 passed a clean
installation, all eight regression tests, TypeScript/Vite production build and
lint with zero warnings. The full audit still reports nine high-severity affected
dependency entries through this one upstream advisory, with no low, moderate or
critical entries. These are propagated package entries, not nine separate bugs.

The advisory affects tool inputs such as glob patterns and repository paths.
These dependencies are used during development/build; this change does not prove
that every application input or deployed package is unaffected. It makes no
changes to Entra, authentication, infrastructure, permissions or deployment.
`npm audit` still reports the published affected range because it cannot inspect
this local mitigation. Do not suppress its findings or label the tree advisory
free. The separate mitigation task MWID-008 does not close MWID-007.

When a supported upstream fix is available, review all dependency paths, remove
the corresponding transformations/helper and installation hook together, and
retain the adverse-input and normal behavior tests against the upstream package.
Re-run clean installation, client build and lint, and record the full audit.
Deployment/login acceptance remains MWID-002.
