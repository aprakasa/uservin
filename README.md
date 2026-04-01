# uservin

Ubuntu Server Initialization Tool

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-blue.svg)](https://www.gnu.org/software/bash/)

**uservin** is a comprehensive Ubuntu server initialization script that automates the setup of fresh Ubuntu installations with security hardening, user management, system optimization, and intelligent configuration.

## Features

- **Interactive Wizard** - Step-by-step configuration with sensible defaults
- **Security Hardening** - SSH key authentication, firewall configuration, fail2ban
- **Safety Features** - Pre-flight checks, automatic backups, rollback capability
- **Intelligent Tuning** - Auto-detects system specs and recommends optimal settings
- **Comprehensive Logging** - Detailed logs with quiet and verbose modes
- **Dry Run Mode** - Preview all changes before applying them
- **Config File Support** - Use configuration files for unattended deployment

## What's Configured

### System
- Hostname configuration
- Timezone setup
- Package updates and essential packages
- System locale configuration

### Security
- SSH hardening (disable root login, password auth)
- UFW firewall configuration
- fail2ban intrusion prevention
- Automatic security updates

### Users
- Non-root admin user creation
- SSH key authentication setup
- Sudo privileges configuration

### Performance
- Swap configuration (optional)
- ZRAM setup (optional)
- System tuning based on available resources

## Requirements

- **OS**: Ubuntu 20.04, 22.04, or 24.04 LTS
- **Access**: Root access (script must run as root)
- **Network**: Internet connection for package installation
- **SSH Key**: Valid SSH public key for user authentication
- **Bash**: Version 4.0 or higher

## Quick Start

### 1. Download

```bash
curl -LO https://github.com/example/uservin/releases/latest/download/uservin.sh
chmod +x uservin.sh
```

### 2. Run

```bash
sudo ./uservin.sh
```

### 3. Follow the Wizard

The interactive wizard will guide you through:
- Hostname configuration
- Timezone selection
- Admin user creation
- SSH key setup
- SSH port configuration
- Auto-update preferences
- Performance tuning options

### 4. Connect

After completion, connect as your new admin user:

```bash
ssh -p <port> <username>@<hostname>
```

## Usage Options

### Dry Run
Preview all changes without applying them:

```bash
sudo ./uservin.sh --dry-run
```

### Quiet Mode
Minimal output (errors only):

```bash
sudo ./uservin.sh --quiet
# or
sudo ./uservin.sh -q
```

### Verbose Mode
Detailed output with debug information:

```bash
sudo ./uservin.sh --verbose
# or
sudo ./uservin.sh -v
```

### Config File
Use a configuration file for unattended deployment:

```bash
sudo ./uservin.sh --config config.ini
```

See [config.example.ini](config.example.ini) for configuration file format.

### Show Help

```bash
./uservin.sh --help
```

### Show Version

```bash
./uservin.sh --version
```

## Safety Features

### Pre-flight Checks
- Ubuntu version validation
- Root access verification
- Required tool availability
- Internet connectivity test
- Disk space verification

### Backup System
- Automatic backup of modified files
- Backup location: `/root/uservin-backups/`
- Timestamped backups for easy restoration

### Rollback
- Rollback capability for critical operations
- Automatic rollback on failures
- Manual rollback script included

## Troubleshooting

### Lost SSH Connection
If you lose SSH connection during setup:
1. Wait 2-3 minutes for the script to complete
2. Reconnect using the new SSH port (if changed)
3. Check `/var/log/uservin.log` for completion status

### Script Failed
If the script fails:
1. Check the error message displayed
2. Review logs: `sudo cat /var/log/uservin.log`
3. Run with verbose mode: `sudo ./uservin.sh --verbose`

### Port Already in Use
If your chosen SSH port is already in use:
1. Check with: `sudo ss -tlnp | grep <port>`
2. Choose a different port (1024-65535)
3. Common ports to avoid: 80, 443, 3306, 5432

### Permission Denied
If you get permission errors:
- Ensure you're running as root: `sudo ./uservin.sh`
- Check script permissions: `chmod +x uservin.sh`

## Security Considerations

- **SSH Key Required**: Password authentication is disabled; SSH key is mandatory
- **Root Login Disabled**: Direct root login is disabled for security
- **UFW Firewall**: Automatically configured with SSH port allowed
- **fail2ban**: Installed and configured to prevent brute-force attacks
- **Automatic Updates**: Security updates can be automatically applied
- **Backup Files**: Original configuration files are backed up before modification

## System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| RAM | 512 MB | 1 GB+ |
| Disk | 10 GB | 20 GB+ |
| CPU | 1 core | 2+ cores |
| Network | 1 Mbps | 10 Mbps+ |

## Tested On

### Ubuntu Versions
- Ubuntu 20.04 LTS (Focal Fossa)
- Ubuntu 22.04 LTS (Jammy Jellyfish)
- Ubuntu 24.04 LTS (Noble Numbat)

### Cloud Providers
- DigitalOcean Droplets
- AWS EC2
- Google Cloud Platform
- Linode
- Vultr
- Hetzner Cloud

## Testing

Run the test suite:

```bash
# Run all tests
cd tests
./run_tests.sh

# Run specific test file
./run_tests.sh test_utils.sh
```

The test suite includes:
- Unit tests for all library modules
- Integration tests for complete workflows
- Mock tests for safe dry-run verification

## Contributing

1. **Fork** the repository on GitHub
2. **Create** a feature branch: `git checkout -b feature/my-feature`
3. **Make** your changes
4. **Test** your changes: `./tests/run_tests.sh`
5. **Commit** with clear messages following conventional commits
6. **Push** to your fork: `git push origin feature/my-feature`
7. **Submit** a Pull Request

### Development Setup

```bash
git clone https://github.com/example/uservin.git
cd uservin
./tests/run_tests.sh
```

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/example/uservin/issues)
- **Discussions**: [GitHub Discussions](https://github.com/example/uservin/discussions)
- **Wiki**: [GitHub Wiki](https://github.com/example/uservin/wiki)

---

**Note**: Always test on a non-production server first. Review the dry-run output before applying changes to production systems.
