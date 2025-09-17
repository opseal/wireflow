---
name: Bug report
about: Create a report to help us improve
title: '[BUG] '
labels: bug
assignees: ''

---

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Environment (please complete the following information):**
 - OS: [e.g. Ubuntu 20.04, macOS 12.0, Windows 11]
 - Kubernetes version: [e.g. 1.24.0]
 - Cloud provider: [e.g. AWS, GCP, Azure, local]
 - VPN version: [e.g. 1.0.0]

**Logs**
Please include relevant logs from:
- VPN API: `kubectl logs -f deployment/vpn-api -n vpn-system`
- WireGuard: `kubectl logs -f deployment/vpn-wireguard -n vpn-system`
- System logs: `journalctl -u wireguard`

**Additional context**
Add any other context about the problem here.

**Checklist**
- [ ] I have searched existing issues to avoid duplicates
- [ ] I have provided all required information
- [ ] I have included relevant logs
- [ ] I have tested with the latest version






