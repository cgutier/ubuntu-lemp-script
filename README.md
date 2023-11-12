# Ubuntu Web Server Setup Scripts

This repository contains two bash scripts that automate the setup of an Ubuntu web server for hosting WordPress sites on a LEMP stack (Nginx, PHP, MariaDB). 

## Scripts

1. `web_server_setup.sh`: This script sets up the base server, including user creation with sudo privileges, SSH configuration, firewall setup, and installation of Nginx, MariaDB, PHP, and essential security and monitoring tools.

2. `wordpress_setup.sh`: This script sets up WordPress on the server, including database and user creation, WordPress download and configuration, Nginx site configuration, and SSL setup with Let's Encrypt.

## Prerequisites

- A fresh Ubuntu server
- Root access to the server

## Usage

### web_server_setup.sh

1. Copy the script to your Ubuntu server.
2. Make the script executable:

```bash
chmod +x web_server_setup.sh
```

3. Run the script as root:

```bash
sudo ./web_server_setup.sh
```

4. Secure your MariaDB installation:

```bash
mysql_secure_installation
```

5. Re-start your server:

```bash
shutdown -r now
```

### wordpress_setup.sh

1. Copy the script to your Ubuntu server.
2. Make the script executable:

```bash
chmod +x wordpress_setup.sh
```

3. Run the script as root:

```bash
sudo ./wordpress_setup.sh
```

## Input Prompts

The scripts will prompt you for the following information:

### web_server_setup.sh
- New user's name
- New user's password (hidden input)
- Preferred SSH port (default: 22)
- Timezone (default: America/Chicago)
- MariaDB root password (hidden input)

### wordpress_setup.sh
- Domain name
- Redirection preference (www to root or not)
- Database name (default: domain name)
- Database user name (default: random 6 alphabetic characters)
- Database user password
- Email address for Let's Encrypt

## Post-Setup Actions

After running the scripts, you may need to configure Nginx and WordPress to suit your specific needs.

## Security Notes

- The scripts disable root SSH login and set up a user with sudo privileges.
- They change the default SSH port to a value you provide.
- Fail2Ban is installed and configured to protect against unauthorized access attempts.
- Unattended-upgrades are configured to automatically apply security updates.

## Important Information

- Make sure to remember the passwords you set during the execution of these scripts.
- The scripts assume standard paths for configuration files; if your server differs, you may need to adjust the scripts accordingly.

## Contributing

If you'd like to contribute to these scripts or report issues, please open an issue or pull request in the repository.

## License

These scripts are open-source and are provided under the MIT License. See the LICENSE file for more information.

---

**Note**: This README is for documentation purposes. Please ensure you understand the scripts and their implications before running them on your server.
```