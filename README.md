# auditd auto install

## Requirements

- Linux based system (Debian/Ubuntu, RHEL/CentOS, Fedora, etc.)
- `sudo` privileges

## Installation

1. Clone the Repository

```bash
git clone https://github.com/Aerysh/auditd.git
cd auditd
```

2. Run the installation script

```bash
chmod +x install.sh
sudo ./install.sh
```

3. Check if environments need reboot

```bash
if [[ $(auditctl -s | grep "enabled") =~ "2" ]]; then printf "Reboot required to load rules\n"; fi
```

## Verification

After installation, verify that `auditd` service is active:

```bash
sudo systemctl status auditd.service
```

Then confirm that audit rules have been loaded:

```bash
sudo auditctl -l
```

## Notes

- The script modify system audit rules. Review `install.sh` before running in production environments.
