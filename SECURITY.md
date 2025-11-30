# Security Policy

## Supported Versions

We release patches for security vulnerabilities for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 0.9.x   | :white_check_mark: |
| < 0.9   | :x:                |

## Reporting a Vulnerability

We take security seriously. If you discover a security vulnerability, please report it responsibly.

### How to Report

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please send an email to: **info@swiftly-developed.com**

Include the following information:
- Type of vulnerability
- Full paths of source file(s) related to the vulnerability
- Location of the affected source code (tag/branch/commit or direct URL)
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue and how an attacker might exploit it

### What to Expect

1. **Acknowledgment**: We will acknowledge receipt of your report within 48 hours
2. **Assessment**: We will assess the vulnerability and determine its severity
3. **Updates**: We will keep you informed of our progress
4. **Resolution**: We aim to resolve critical vulnerabilities within 7 days
5. **Disclosure**: We will coordinate with you on public disclosure timing

### Safe Harbor

We consider security research conducted in accordance with this policy to be:
- Authorized concerning any applicable anti-hacking laws
- Authorized concerning any relevant anti-circumvention laws
- Exempt from restrictions in our Terms of Service that would interfere with conducting security research

We will not pursue civil action or initiate a complaint to law enforcement for accidental, good faith violations of this policy.

## Security Best Practices for Users

### API Key Management

- **Never commit API keys** to version control
- Use environment variables or secure vaults
- Rotate keys regularly
- Use separate keys for development and production

### Network Security

- Always use HTTPS for API communications
- Validate SSL certificates
- Consider using certificate pinning for sensitive applications

### Data Handling

- Don't log sensitive data (API keys, user content)
- Implement proper error handling that doesn't expose internals
- Consider data retention policies for AI responses

## Security Features

SwiftlyAIKit includes several security features:

- **No credential storage**: API keys are passed at runtime, not stored
- **Secure defaults**: HTTPS-only communication
- **Input validation**: Request validation before API calls
- **Error sanitization**: Sensitive data removed from error messages

## Acknowledgments

We appreciate the security research community's efforts in helping keep SwiftlyAIKit secure. Contributors who report valid vulnerabilities will be acknowledged (with permission) in our security advisories.
