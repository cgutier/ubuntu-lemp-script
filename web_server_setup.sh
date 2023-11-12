#!/bin/bash

# Define color and formatting variables
INFO='\033[1;34m' # Blue
WARN='\033[1;33m' # Yellow
ERR='\033[1;31m' # Red
NC='\033[0m' # No Color

# Function to create a spinner animation while updates and installations run in the background
spinner() {
    local pid=$1
    local delay=0.75
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Create a new user with sudo privileges
echo -e "${INFO}Enter your username: ${NC}"
read username
echo -e "${INFO}Creating a new user with sudo privileges...${NC}"
useradd -m -s /bin/bash $username
echo -e "${INFO}Enter password for new user $username: ${NC}"
passwd $username
usermod -aG sudo $username # Add the user to the sudo group
echo "$username ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/$username > /dev/null
chmod 0440 /etc/sudoers.d/$username # Set proper permissions for the sudoers file

# Prompting user for input
echo -e "${INFO}Enter your preferred SSH port [default: 22]: ${NC}"
read input_ssh_port
ssh_port=${input_ssh_port:-22} # Default to 22 if input is empty
echo -e "${INFO}Enter your timezone [default: America/Chicago]: ${NC}"
read input_timezone
timezone=${input_timezone:-America/Chicago} # Default to America/Chicago if input is empty
echo -e "${INFO}Enter your MariaDB root password: ${NC}"
read -s root_password

# Set the timezone
echo -e "${INFO}Setting the timezone...${NC}"
timedatectl set-timezone $timezone

# Update and upgrade system packages quietly in the background while showing the spinner animation
echo -e "${INFO}Updating system packages...${NC}"
apt-get update -qq &>/dev/null & spinner $!
apt-get upgrade -y -qq &>/dev/null & spinner $!

# Disable root login
echo -e "${INFO}Disabling root login...${NC}"
sed -i '/PermitRootLogin yes/c\PermitRootLogin no' /etc/ssh/sshd_config
# Change the SSH port
echo -e "${INFO}Changing the SSH port...${NC}"
sed -i "s/#Port 22/Port $ssh_port/" /etc/ssh/sshd_config

# Install and configure Fail2Ban
echo -e "${INFO}Installing and configuring Fail2Ban...${NC}"
apt-get install fail2ban -y -qq &>/dev/null & spinner $!
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
systemctl enable fail2ban &>/dev/null
systemctl start fail2ban &>/dev/null

# Set up automatic updates
echo -e "${INFO}Setting up automatic updates...${NC}"
apt-get install unattended-upgrades -y -qq &>/dev/null & spinner $!
dpkg-reconfigure -plow unattended-upgrades

# Firewall configuration
echo -e "${INFO}Configuring the firewall...${NC}"
ufw default deny incoming > /dev/null
ufw default allow outgoing > /dev/null
ufw allow $ssh_port/tcp > /dev/null
ufw allow http > /dev/null
ufw allow https > /dev/null
ufw --force enable > /dev/null

# Install and configure Nginx
echo -e "${INFO}Installing Nginx...${NC}"
apt-get install nginx -y -qq &>/dev/null & spinner $!

# Install PHP and required extensions
echo -e "${INFO}Installing PHP and extensions...${NC}"
apt-get install php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip php-imagick -y -qq &>/dev/null & spinner $!

# Configure PHP settings
echo -e "${INFO}Configuring PHP settings...${NC}"
PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
PHP_INI="/etc/php/${PHP_VER}/fpm/php.ini"
sed -i "s/memory_limit = .*/memory_limit = 256M/" $PHP_INI
sed -i "s/upload_max_filesize = .*/upload_max_filesize = 64M/" $PHP_INI
sed -i "s/post_max_size = .*/post_max_size = 64M/" $PHP_INI
sed -i "s/max_execution_time = .*/max_execution_time = 300/" $PHP_INI

# Install and secure MariaDB
echo -e "${INFO}Installing MariaDB...${NC}"
apt-get install mariadb-server -y -qq &>/dev/null & spinner $!

# Secure the MariaDB installation
echo -e "${INFO}Securing MariaDB installation...${NC}"
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$root_password';" # Set the root password

# System monitoring tools installation
echo -e "${INFO}Setting up system monitoring tools...${NC}"
apt-get install htop iftop -y -qq &>/dev/null & spinner $!

# Install nano for file editing
echo -e "${INFO}Installing nano...${NC}"
apt-get install nano -y -qq &>/dev/null & spinner $!

# Install Git
echo -e "${INFO}Installing Git...${NC}"
apt-get install git -y -qq &>/dev/null & spinner $!

# Restart Nginx to apply all configurations
echo -e "${INFO}Restarting Nginx...${NC}"
systemctl restart nginx

# Add echo for each step
echo -e "${GREEN}Script execution completed.${NC}"