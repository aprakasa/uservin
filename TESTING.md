# Testing Documentation

This document provides comprehensive testing guidelines for the uservin project.

## Table of Contents

- [Unit Testing](#unit-testing)
- [Syntax Validation](#syntax-validation)
- [Pre-deployment Testing](#pre-deployment-testing)
- [Security Testing](#security-testing)
- [Error Handling](#error-handling)
- [Post-deployment Verification](#post-deployment-verification)
- [Final Checklist](#final-checklist)

---

## Unit Testing

### Running All Tests

Execute the test suite using the provided runner script:

```bash
bash tests/runner.sh
```

### Expected Results

- All tests pass with no failures
- Output format:
  ```
  ✓ test_log_level_default
  ✓ test_dry_run_default
  ✓ test_validate_port_valid
  ...
  
  Passed: X
  Failed: 0
  ```

### Running Individual Test Files

```bash
# Run specific test module
bash tests/runner.sh test_utils.sh

# Run multiple specific tests
bash tests/runner.sh test_utils.sh test_security.sh
```

### Test Coverage

The following modules have unit tests:

| Module | Test File | Coverage |
|--------|-----------|----------|
| utils.sh | test_utils.sh | Logging, validation functions, command checks |
| security.sh | test_security.sh | SSH hardening, firewall, fail2ban |
| user.sh | test_user.sh | User creation, SSH key setup |
| system.sh | test_system.sh | Hostname, timezone, packages |
| wizard.sh | test_wizard.sh | Interactive prompts, validation |
| performance.sh | test_performance.sh | Swap, ZRAM, tuning |
| safety.sh | test_safety.sh | Backups, rollback, pre-flight checks |
| report.sh | test_report.sh | Log generation, status reports |

---

## Syntax Validation

### Validate All Shell Scripts

Run the following command to validate syntax of all `.sh` files:

```bash
#!/bin/bash
# validate_syntax.sh - Validate all shell scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERRORS=0

echo "Validating shell script syntax..."

# Validate main script
if ! bash -n "$SCRIPT_DIR/uservin.sh"; then
    echo "ERROR: Syntax error in uservin.sh"
    ((ERRORS++))
fi

# Validate library files
for lib in "$SCRIPT_DIR"/lib/*.sh; do
    if [[ -f "$lib" ]]; then
        if ! bash -n "$lib"; then
            echo "ERROR: Syntax error in $lib"
            ((ERRORS++))
        fi
    fi
done

# Validate test files
for test in "$SCRIPT_DIR"/tests/*.sh; do
    if [[ -f "$test" ]]; then
        if ! bash -n "$test"; then
            echo "ERROR: Syntax error in $test"
            ((ERRORS++))
        fi
    fi
done

if [[ $ERRORS -eq 0 ]]; then
    echo "✓ All files have valid syntax"
    exit 0
else
    echo "✗ Found $ERRORS file(s) with syntax errors"
    exit 1
fi
```

### Manual Validation

Validate individual files:

```bash
bash -n uservin.sh
bash -n lib/utils.sh
bash -n lib/security.sh
bash -n tests/runner.sh
```

### Validation Checklist

- [ ] `bash -n` returns 0 for all `.sh` files
- [ ] No syntax errors in main script
- [ ] No syntax errors in library files
- [ ] No syntax errors in test files

---

## Pre-deployment Testing

### Test Environment Setup

Prepare test environments on the following Ubuntu versions:

| Ubuntu Version | Status | Notes |
|----------------|--------|-------|
| Ubuntu 20.04 LTS | Required | Focal Fossa |
| Ubuntu 22.04 LTS | Required | Jammy Jellyfish |
| Ubuntu 24.04 LTS | Required | Noble Numbat |

**VM Specifications for Testing:**
- Provider: VirtualBox, VMware, or cloud instances
- Network: Bridged/NAT with internet access
- Clean installation (no prior configuration)

### Test Scenarios

#### Scenario 1: Basic Setup

**Objective:** Test default configuration with minimal inputs

**Steps:**
1. Start with clean Ubuntu VM
2. Run: `sudo ./uservin.sh`
3. Provide inputs:
   - Hostname: `test-server`
   - Timezone: `Asia/Jakarta`
   - Username: `admin`
   - SSH Key: valid SSH public key
   - SSH Port: `22` (default)
   - Auto-updates: `yes`
   - Swap: `no`
   - ZRAM: `yes`

**Expected Results:**
- [ ] Script completes without errors
- [ ] Hostname is set correctly
- [ ] User `admin` is created
- [ ] SSH key is added to user's authorized_keys
- [ ] UFW is enabled with SSH port open
- [ ] fail2ban is installed and running
- [ ] Can SSH as `admin` user with key

#### Scenario 2: Custom SSH Port

**Objective:** Test non-standard SSH port configuration

**Steps:**
1. Start with clean Ubuntu VM
2. Run: `sudo ./uservin.sh`
3. Provide inputs:
   - SSH Port: `2222` (non-standard)

**Expected Results:**
- [ ] SSH service listens on port 2222
- [ ] UFW allows port 2222
- [ ] fail2ban monitors port 2222
- [ ] Can SSH on port 2222
- [ ] Port 22 is blocked or SSH service moved

#### Scenario 3: Low Memory System (1GB)

**Objective:** Test behavior on resource-constrained system

**Environment:**
- RAM: 1 GB
- CPU: 1 core

**Steps:**
1. Configure VM with 1GB RAM
2. Run: `sudo ./uservin.sh`
3. Accept recommended settings for low memory

**Expected Results:**
- [ ] Script detects low memory
- [ ] Recommends swap file creation
- [ ] ZRAM configuration suggested
- [ ] Performance tuning adjusted for low resources
- [ ] No OOM (Out of Memory) errors during execution

#### Scenario 4: High Memory System (8GB+)

**Objective:** Test optimization on high-resource system

**Environment:**
- RAM: 8 GB+
- CPU: 4+ cores

**Steps:**
1. Configure VM with 8GB+ RAM
2. Run: `sudo ./uservin.sh`

**Expected Results:**
- [ ] Script detects high memory
- [ ] Suggests no swap (or minimal swap)
- [ ] Performance tuning optimized for high resources
- [ ] All services start without resource constraints

#### Scenario 5: Dry Run Mode

**Objective:** Verify dry-run mode shows changes without applying

**Steps:**
1. Start with clean Ubuntu VM
2. Run: `sudo ./uservin.sh --dry-run`
3. Review output

**Expected Results:**
- [ ] Script shows all intended changes
- [ ] No actual changes are made to system
- [ ] Hostname remains unchanged
- [ ] No new user created
- [ ] SSH config not modified
- [ ] Log file shows dry-run operations

#### Scenario 6: Rollback

**Objective:** Test rollback functionality on failure

**Steps:**
1. Start with clean Ubuntu VM
2. Induce a failure (e.g., full disk, invalid input)
3. Verify rollback restores previous state

**Expected Results:**
- [ ] Backup created before changes
- [ ] Original configurations preserved
- [ ] Rollback script available
- [ ] System restored to original state
- [ ] No partial configurations left

#### Scenario 7: SSH Key Only

**Objective:** Test that password authentication is disabled

**Steps:**
1. Complete normal installation
2. Attempt to SSH with password

**Expected Results:**
- [ ] Password authentication rejected
- [ ] Key authentication works
- [ ] Root login disabled
- [ ] Only created user can log in

---

## Security Testing

### Security Checklist

#### SSH Configuration
- [ ] Root login disabled (`PermitRootLogin no`)
- [ ] Password authentication disabled (`PasswordAuthentication no`)
- [ ] Only specified SSH key works for authentication
- [ ] SSH service restarted successfully
- [ ] Previous SSH sessions remain active during transition

#### Firewall (UFW)
- [ ] UFW is enabled and active
- [ ] Only configured SSH port is open
- [ ] Default deny policy in place
- [ ] Rules persist after reboot

#### fail2ban
- [ ] fail2ban service is running
- [ ] SSH jail is enabled
- [ ] Ban rules are configured
- [ ] Log monitoring is active

#### User Security
- [ ] Non-root user created with sudo access
- [ ] User password set (if applicable)
- [ ] SSH key properly configured
- [ ] User home directory permissions correct (700)
- [ ] `.ssh` directory permissions correct (700)
- [ ] `authorized_keys` file permissions correct (600)

#### Automatic Updates
- [ ] unattended-upgrades installed
- [ ] Security updates enabled
- [ ] Configuration file created at `/etc/apt/apt.conf.d/50unattended-upgrades`

### Security Verification Commands

```bash
# Check SSH configuration
grep -E "^(PermitRootLogin|PasswordAuthentication)" /etc/ssh/sshd_config

# Check UFW status
sudo ufw status verbose

# Check fail2ban status
sudo fail2ban-client status
sudo fail2ban-client status sshd

# Check user sudo access
sudo -l -U <username>

# Check file permissions
ls -la /home/<username>/.ssh/
ls -la /home/<username>/.ssh/authorized_keys

# Check unattended-upgrades
cat /etc/apt/apt.conf.d/50unattended-upgrades | grep -A5 "Unattended-Upgrade::Allowed-Origins"
```

---

## Error Handling

### Invalid Input Testing

Test the script's response to invalid inputs:

#### Invalid Hostname
- [ ] Empty hostname → Error message, reprompt
- [ ] Hostname with spaces → Error message, reprompt
- [ ] Hostname starting with hyphen → Error message, reprompt
- [ ] Hostname with special characters → Error message, reprompt
- [ ] Very long hostname (>63 chars) → Error message, reprompt

#### Invalid Username
- [ ] Empty username → Error message, reprompt
- [ ] Username starting with number → Error message, reprompt
- [ ] Username with special characters → Error message, reprompt
- [ ] Existing system username → Error message, reprompt
- [ ] Reserved username (root, admin, etc.) → Warning or error

#### Invalid SSH Key
- [ ] Empty key → Error message, reprompt
- [ ] Invalid key format → Error message, reprompt
- [ ] Private key instead of public → Error message, reprompt
- [ ] Key with extra whitespace → Trimmed and validated

#### Invalid SSH Port
- [ ] Empty port → Error message, reprompt
- [ ] Port < 1 → Error message, reprompt
- [ ] Port > 65535 → Error message, reprompt
- [ ] Port already in use → Warning, allow or reprompt
- [ ] Reserved port (0-1023) without proper justification → Warning

#### Invalid Timezone
- [ ] Empty timezone → Error message, reprompt
- [ ] Invalid timezone name → Error message, reprompt
- [ ] Non-existent timezone → Error message, reprompt

### Error Recovery Testing

- [ ] Network interruption during package install → Graceful error, clear message
- [ ] Disk full during operation → Graceful error, offer rollback
- [ ] Permission denied on critical file → Clear error message
- [ ] Service fails to start → Log error, continue or rollback
- [ ] Configuration file parse error → Clear error message, exit

### Command-Line Error Testing

```bash
# Invalid options
sudo ./uservin.sh --invalid-option    # Should show error and help
sudo ./uservin.sh -x                  # Should show error and help

# Missing config file
sudo ./uservin.sh --config /nonexistent/file.ini  # Should error

# Non-root execution
./uservin.sh                          # Should error - requires root
```

---

## Post-deployment Verification

### System State Checks

#### Hostname
```bash
hostnamectl status
# Expected: Static hostname matches configured value
```

#### Timezone
```bash
timedatectl status
# Expected: Timezone matches configured value
```

#### Packages
```bash
# Check essential packages are installed
dpkg -l | grep -E "(ufw|fail2ban|unattended-upgrades)"
# Expected: All security packages installed
```

#### Services
```bash
# Check services are running
systemctl is-active ufw
systemctl is-active fail2ban
systemctl is-active ssh
# Expected: All return "active"
```

### Connectivity Checks

#### SSH Access
```bash
# Test SSH connectivity
ssh -p <port> <username>@<hostname>
# Expected: Successful login with key, no password prompt

# Test that password auth fails
ssh -o PubkeyAuthentication=no -p <port> <username>@<hostname>
# Expected: Permission denied

# Test root login fails
ssh -p <port> root@<hostname>
# Expected: Permission denied
```

#### Network Connectivity
```bash
# Test internet connectivity
ping -c 3 8.8.8.8
# Expected: 0% packet loss

# Test DNS resolution
nslookup google.com
# Expected: Successful resolution
```

#### Firewall Rules
```bash
# Check UFW rules
sudo ufw status numbered
# Expected: Configured SSH port listed as ALLOW

# Test port connectivity (from external)
nc -zv <server-ip> <ssh-port>
# Expected: Connection successful
```

### Log File Checks

#### Main Log
```bash
# Check uservin log exists and is readable
ls -la /var/log/uservin.log
# Expected: File exists, readable

# Check for errors
grep -i "error\|fail\|critical" /var/log/uservin.log
# Expected: No critical errors (some warnings may be OK)

# Check completion status
tail -20 /var/log/uservin.log
# Expected: "uservin completed successfully" or similar
```

#### System Logs
```bash
# Check SSH logs for authentication attempts
sudo grep sshd /var/log/auth.log | tail -20
# Expected: Recent successful key-based logins

# Check fail2ban logs
sudo grep fail2ban /var/log/fail2ban.log | tail -20
# Expected: Service started, monitoring active
```

### Backup Verification

```bash
# Check backup directory exists
ls -la /root/uservin-backups/
# Expected: Directory exists with timestamped backups

# Verify backup contents
ls -la /root/uservin-backups/*/
# Expected: Contains original config files
```

---

## Final Checklist

### Test Completion

- [ ] All unit tests pass (`bash tests/runner.sh`)
- [ ] All syntax validation passes (`bash -n` on all files)
- [ ] All scenarios tested on Ubuntu 20.04
- [ ] All scenarios tested on Ubuntu 22.04
- [ ] All scenarios tested on Ubuntu 24.04
- [ ] Dry-run mode tested on all versions
- [ ] Rollback functionality tested
- [ ] Security checklist verified

### Code Quality

- [ ] TDD (Test-Driven Development) followed
- [ ] All new features have corresponding tests
- [ ] Test coverage is adequate (>80% for critical paths)
- [ ] No sensitive data in test files
- [ ] No hardcoded credentials in code

### Documentation

- [ ] README.md is accurate and up-to-date
- [ ] This TESTING.md is complete
- [ ] All command examples are tested and working
- [ ] Configuration examples are valid
- [ ] Troubleshooting section covers common issues

### Git Commits

- [ ] Semantic commit messages used
- [ ] Commit history is clean and meaningful
- [ ] No sensitive data in commit history
- [ ] Feature branches properly merged

### Security Review

- [ ] No secrets or credentials in code
- [ ] No hardcoded passwords or keys
- [ ] Log files don't contain sensitive data
- [ ] Backup files are secure (readable only by root)
- [ ] Input validation is comprehensive
- [ ] Error messages don't leak sensitive info

### Release Readiness

- [ ] Version number updated
- [ ] CHANGELOG.md updated (if applicable)
- [ ] License file present
- [ ] All tests pass in CI/CD (if applicable)
- [ ] Manual testing completed successfully
- [ ] Documentation reviewed

---

## Testing Commands Quick Reference

```bash
# Run all tests
bash tests/runner.sh

# Run specific test
bash tests/runner.sh test_utils.sh

# Validate syntax
bash -n uservin.sh && echo "OK" || echo "FAIL"

# Dry run
sudo ./uservin.sh --dry-run

# Verbose mode for debugging
sudo ./uservin.sh --verbose

# Check logs
sudo tail -f /var/log/uservin.log

# View backup
ls -la /root/uservin-backups/

# Test SSH
ssh -p <port> <user>@<host>
```

---

## Notes

- Always test on non-production systems first
- Create snapshots before testing destructive scenarios
- Document any issues found during testing
- Update this document if new test scenarios are discovered
- Test on actual hardware if possible (not just VMs)

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-04-01 | Initial testing documentation |
