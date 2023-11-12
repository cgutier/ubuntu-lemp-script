#!/bin/bash

# Define color and formatting variables
INFO='\033[1;34m' # Blue
WARN='\033[1;33m' # Yellow
ERR='\033[1;31m' # Red
NC='\033[0m' # No Color

# Function to generate a random string for the database user
generate_random_string() {
    cat /dev/urandom | tr -dc 'a-z' | fold -w 6 | head -n 1
}

# Prompting user for input
echo -e "${INFO}Enter your domain name: ${NC}"
read domain_name
echo -e "${INFO}Do you want to redirect www.$domain_name to $domain_name? [1 = Yes, 2 = No] [default: 1]: ${NC}"
read redirect_choice
redirect_choice=${redirect_choice:-1} # Default to 1 if input is empty
db_name="${domain_name//./_}" # Replace dots with underscores in domain name for DB name
echo -e "${INFO}Enter database name [default: $db_name]: ${NC}"
read input_db_name
db_name=${input_db_name:-$db_name} # Default to domain name if input is empty
random_user=$(generate_random_string)
echo -e "${INFO}Enter database user name [default: $random_user]: ${NC}"
read input_db_user
db_user=${input_db_user:-$random_user} # Default to random user if input is empty
echo -e "${INFO}Enter database user password: ${NC}"
read -s db_user_pass
echo -e "${INFO}Enter email address for Let's Encrypt: ${NC}"
read letsencrypt_email

# Creating the database and user
echo -e "${INFO}Creating database and user...${NC}"
echo -e "${INFO}Enter MariaDB root password: ${NC}"
mysql -u root -p <<EOF
CREATE DATABASE $db_name;
CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_user_pass';
GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';
FLUSH PRIVILEGES;
EOF

# Check if WP-CLI is installed, if not, install it
if ! command -v wp &> /dev/null
then
    echo -e "${INFO}WP-CLI not found, installing...${NC}"
    curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    sudo mv wp-cli.phar /usr/local/bin/wp
fi

# Creating WordPress installation folder
echo -e "${INFO}Setting up WordPress...${NC}"
wp_dir="/var/www/$domain_name"
mkdir -p $wp_dir

# Download and configure WordPress using WP-CLI
wp --allow-root core download --path=$wp_dir --quiet
wp --allow-root config create --dbname=$db_name --dbuser=$db_user --dbpass=$db_user_pass --path=$wp_dir --quiet

# Set the right permissions for WordPress
chown -R www-data:www-data $wp_dir

# Setting up Nginx site configuration
echo -e "${INFO}Configuring Nginx and SSL...${NC}"
php_ver=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
nginx_conf="/etc/nginx/sites-available/$domain_name"

# Create a new Nginx configuration file
if [ "$redirect_choice" -eq 1 ]; then
    echo "server {
        listen 80;
        listen [::]:80;
        server_name www.$domain_name;
        return 301 \$scheme://$domain_name\$request_uri;
    }" > $nginx_conf
fi

echo "server {
    listen 80;
    listen [::]:80;
    server_name $domain_name;

    root $wp_dir;
    index index.php index.html index.htm;

    access_log /var/log/nginx/$domain_name.access.log;
    error_log /var/log/nginx/$domain_name.error.log;

    # Set maximum upload size
    client_max_body_size 64M;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${php_ver}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }

    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    location ~* \.(css|gif|ico|jpeg|jpg|js|png)$ {
        expires max;
        log_not_found off;
    }
}" >> $nginx_conf

# Enable site and check configuration
ln -s /etc/nginx/sites-available/$domain_name /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx

# Setting up Let's Encrypt for SSL
echo -e "${INFO}Setting up Let's Encrypt for SSL...${NC}"
if ! command -v certbot &> /dev/null
then
    apt-get install software-properties-common -y -qq
    add-apt-repository ppa:certbot/certbot -y
    apt-get update -y -qq
    apt-get install certbot python3-certbot-nginx -y -qq
fi

# Include www for Let's Encrypt only if the user wants to redirect www to root domain
if [ "$redirect_choice" -eq 1 ]; then
    certbot --nginx -d $domain_name -d www.$domain_name --non-interactive --agree-tos --email $letsencrypt_email --redirect
else
    certbot --nginx -d $domain_name --non-interactive --agree-tos --email $letsencrypt_email --redirect
fi

echo -e "${INFO}WordPress setup on LEMP stack completed.${NC}"