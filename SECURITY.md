# Security Policy

## Reporting a vulnerability

Please do not open a public issue for a security vulnerability.

Email or privately contact the maintainer with:

- A description of the issue
- Steps to reproduce
- Affected files or features
- Any suggested fix

## Security expectations

Clawsheet should avoid:

- Running shell commands from imported content
- Requesting broad filesystem access
- Storing secrets in the repository
- Treating unverified community content as official
- Fetching from sources without clear user visibility

Changes touching entitlements, persistence, source ingestion, or parsing should receive extra review.

