# GoogleRecorderClient

A web client for interfacing with Google Recorder.

## Security

This repository uses automated security scanning to detect exposed API keys and secrets.

### Security Scans

- **Automated scanning:** GitHub Actions runs weekly security scans using [Gitleaks](https://github.com/gitleaks/gitleaks)
- **Pre-commit hooks:** Optional local scanning available (see `.github/hooks/README.md`)
- **Latest scan report:** See `SECURITY_SCAN_REPORT.md` for the most recent security audit

### Running Security Scans Locally

```bash
# Install gitleaks
# macOS
brew install gitleaks

# Linux
wget https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_linux_x64.tar.gz
tar -xzf gitleaks_linux_x64.tar.gz
sudo mv gitleaks /usr/local/bin/

# Run scan on current code
gitleaks detect --source . --verbose

# Run scan on git history
gitleaks detect --source . --log-opts="--all" --verbose
```

### Reporting Security Issues

If you discover a security vulnerability, please report it by emailing the repository maintainers directly rather than opening a public issue.

## Documentation

- [Google Recorder API Specification (Comet)](GoogleRecorderAPIDocs/GoogleAPISpecification(GeneratedByComet).md)
- [Google Recorder API Specification (Gemini)](GoogleRecorderAPIDocs/GoogleAPISpecification(GeneratedByGemini).md)

## Contributing

Please ensure your contributions don't include any secrets or API keys. The pre-commit hook can help catch these before submission.

## License

See LICENSE file for details.
