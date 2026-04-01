# uservin

⚡ Ubuntu Server Initialization Tool - Secure your server in minutes, not hours.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-blue.svg)](https://www.gnu.org/software/bash/)
[![Tests](https://github.com/aprakasa/uservin/workflows/PR%20Checks/badge.svg)](https://github.com/aprakasa/uservin/actions)

**uservin** is a comprehensive Ubuntu server initialization script that automates security hardening, user management, system optimization, and intelligent configuration through an interactive wizard.

## Features

- 🎯 **One-Liner Install** - Single command setup: `wget -qO- URL | sudo bash`
- 🧙 **Interactive Wizard** - Step-by-step configuration with sensible defaults
- 🔒 **Security Hardening** - SSH key authentication, UFW firewall, fail2ban
- 🛡️ **Safety Features** - Dry-run mode, automatic backups, rollback capability
- ⚡ **Performance Tuning** - BBR congestion control, Zram, sysctl optimization
- 🤖 **Auto-Detection** - Detects RAM and recommends swap/Zram settings
- 📝 **Comprehensive Logging** - Detailed logs with quiet and verbose modes
- 🔄 **Auto-Updates** - Configurable automatic security updates

## What's Configured

### System
- Hostname and timezone configuration
- Package updates (apt update/upgrade/dist-upgrade)
- Essential packages installation
- System locale setup

### Security
- SSH hardening (custom port, disable root login, key-only auth)
- UFW firewall with port configuration
- fail2ban intrusion prevention
- Automatic security updates

### Users
- Non-root admin user creation
- SSH key authentication setup
- Sudo privileges configuration
- Passwordless sudo for admin

### Performance
- Linux kernel BBR congestion control
- Zram setup (compressed RAM swap)
- Traditional swap configuration
- Sysctl optimizations based on RAM

## Requirements

- **OS**: Ubuntu 20.04, 22.04, 24.04, or 24.10
- **Access**: Root access (script must run as root)
- **Network**: Internet connection for package installation
- **SSH Key**: Valid SSH public key for user authentication
- **Bash**: Version 4.0 or higher

## Quick Start

### One-Liner Install (Recommended)

```bash
wget -qO- https://github.com/aprakasa/uservin/releases/latest/download/uservin.sh | sudo bash
```

### Traditional Download

```bash
# Download
curl -LO https://github.com/aprakasa/uservin/releases/latest/download/uservin.sh
chmod +x uservin.sh

# Run
sudo ./uservin.sh
```

### Build from Source

```bash
git clone https://github.com/aprakasa/uservin.git
cd uservin
make build
sudo ./uservin.sh
```

## Usage Options

```bash
# Dry run (preview changes without applying)
sudo ./uservin.sh --dry-run

# Quiet mode (errors only)
sudo ./uservin.sh --quiet

# Verbose mode (detailed output)
sudo ./uservin.sh --verbose

# Show help
./uservin.sh --help
```

## Interactive Wizard

The wizard guides you through:
1. **Hostname** - Set server hostname
2. **Timezone** - Configure system timezone
3. **Admin User** - Create non-root user with sudo
4. **SSH Port** - Change from default 22 (optional)
5. **SSH Key** - Add your public key
6. **Auto-Updates** - Enable automatic security updates
7. **Swap/Zram** - Configure based on your RAM:
   - < 4GB RAM: Enable both Zram + Swap
   - 4-8GB RAM: Enable Zram only
   - > 8GB RAM: Your choice
8. **Confirmation** - Review summary before applying

## Safety Features

### Pre-flight Checks
- Ubuntu version validation (20.04/22.04/24.04/24.10)
- Root access verification
- Required tools availability
- Internet connectivity test
- Disk space verification
- SSH key validation

### Backup System
- Automatic backup of all modified files
- Backup location: `/root/uservin-backups/YYYY-MM-DD_HH-MM-SS/`
- Timestamped for easy restoration
- Restore script auto-generated

### Rollback
- Automatic rollback on critical failures
- Trap-based cleanup on script interruption
- Manual rollback anytime via restore script

## Project Structure

```
uservin/
├── uservin.sh          # Bundled single-file script (generated)
├── lib/                # Modular library files
│   ├── utils.sh        # Logging, validation, helpers
│   ├── safety.sh       # Backup, rollback, preflight
│   ├── wizard.sh       # Interactive configuration
│   ├── system.sh       # System updates, packages
│   ├── security.sh     # SSH hardening, firewall
│   ├── user.sh         # User creation, SSH keys
│   ├── performance.sh  # BBR, Zram, swap
│   └── report.sh       # Setup orchestration
├── tests/              # Test suite
├── build.sh            # Build script
└── Makefile            # Build automation
```

## Development

### Build the Bundled Script

```bash
make build    # Generate uservin.sh from lib files
make test     # Run all tests
make clean    # Restore original files
make lint     # Run shellcheck
```

### Running Tests

```bash
cd tests
./runner.sh
```

### Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes to `lib/` files
4. Run `make build` to regenerate `uservin.sh`
5. Run tests: `make test`
6. Commit with conventional commits
7. Push and submit a PR

## CI/CD

This project uses GitHub Actions for:
- **PR Checks** - Tests, shellcheck, build verification
- **Auto-Build** - Regenerates `uservin.sh` on lib changes
- **Releases** - Attaches bundled script to releases
- **Scheduled Tests** - Weekly testing on multiple Ubuntu versions

## Troubleshooting

### Lost SSH Connection
Wait 2-3 minutes and reconnect with your new SSH port:
```bash
ssh -p <port> <username>@<hostname>
```

### Check Logs
```bash
sudo cat /var/log/uservin.log
```

### Port Already in Use
```bash
sudo ss -tlnp | grep <port>
# Choose different port (1024-65535), avoid: 80, 443, 3306
```

## System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| RAM | 512 MB | 1 GB+ |
| Disk | 10 GB | 20 GB+ |
| CPU | 1 core | 2+ cores |
| Network | 1 Mbps | 10 Mbps+ |

## Tested On

- **Ubuntu**: 20.04 LTS, 22.04 LTS, 24.04 LTS, 24.10
- **Cloud**: DigitalOcean, AWS EC2, GCP, Linode, Vultr, Hetzner

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

⚠️ **Note**: Always test on a non-production server first. Use `--dry-run` to preview changes.
