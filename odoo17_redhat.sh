#!/bin/bash

# Function to display colorful billboard message
display_billboard() {
    printf "\e[91m\e[1m==================================================\e[0m\n"
    printf "\e[93m\e[1m%s\e[0m\n" "$1"
    printf "\e[91m\e[1m==================================================\e[0m\n"
}

# Function to prompt user for Odoo version
select_odoo_version() {
    echo "Please select the Odoo version:"
    echo "1) Odoo 14.0"
    echo "2) Odoo 15.0"
    echo "3) Odoo 16.0"
    echo "4) Odoo 17.0"
    read -rp "Enter your choice (1-4): " choice

    case $choice in
        1) OE_BRANCH="14.0";;
        2) OE_BRANCH="15.0";;
        3) OE_BRANCH="16.0";;
        4) OE_BRANCH="17.0";;
        *) echo "Invalid choice. Please enter a number between 1 and 4."; exit 1;;
    esac
}

# Display billboard message
billboard_message="Welcome to the Odoo Production Server Setup Script for RHEL 9!"
display_billboard "$billboard_message"

# Prompt user for Odoo version
select_odoo_version

# Fixed parameters
OE_USER="odoo"

# Add user and group
groupadd "$OE_USER"
useradd --create-home -d /home/"$OE_USER" --shell /bin/bash -g "$OE_USER" "$OE_USER"

# Install EPEL repository
echo -e "\n---- Enabling EPEL Repository ----"
dnf install -y epel-release

# Update system
echo -e "\n---- Update System ----"
dnf update -y

# Install PostgreSQL repository and server
echo -e "\n---- Install PostgreSQL Server ----"
dnf install -y https://download.postgresql.org/pub/repos/yum/releasing/15/redhat/rhel-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm
dnf install -y postgresql15 postgresql15-server postgresql15-devel
/usr/pgsql-15/bin/postgresql-15-setup initdb
systemctl enable postgresql-15
systemctl start postgresql-15
sudo -u postgres createuser -s "$OE_USER"

# Install required tools and dependencies
echo -e "\n---- Installing Required Tools and Dependencies ----"
dnf install -y gcc python3 python3-pip python3-devel git wget nodejs npm libxslt-devel bzip2 freetype-devel libjpeg-devel openldap-devel libtiff-devel cairo-devel

# Install Python libraries
echo -e "\n---- Installing Python Libraries ----"
pip3 install setuptools wheel psycopg2-binary pillow lxml Babel decorator pytz pyparsing Jinja2 MarkupSafe werkzeug pyPDF2 passlib num2words

# Install wkhtmltopdf
if [ "$INSTALL_WKHTMLTOPDF" = "True" ]; then
    echo -e "\n---- Installing wkhtmltopdf ----"
    wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox-0.12.6-1.centos9.x86_64.rpm
    rpm -ivh wkhtmltox-0.12.6-1.centos9.x86_64.rpm
else
    echo "Skipping wkhtmltopdf installation as per user choice."
fi

# Clone Odoo repository
echo -e "\n---- Cloning Odoo Repository ----"
mkdir -p /odoo
git clone --depth 1 --branch "$OE_BRANCH" https://github.com/odoo/odoo.git /odoo
chown -R "$OE_USER:$OE_USER" /odoo

# Create configuration and log directories
echo -e "\n---- Setting Up Configuration ----"
mkdir -p /etc/odoo /var/log/odoo
touch /etc/odoo/odoo.conf
touch /var/log/odoo/odoo-server.log
chown -R "$OE_USER:$OE_USER" /etc/odoo /var/log/odoo

# Install Node.js packages
echo -e "\n---- Installing Node.js Packages ----"
npm install -g less less-plugin-clean-css rtlcss

# Create systemd service file
echo -e "\n---- Setting Up Systemd Service ----"
cat > /etc/systemd/system/odoo.service <<EOF
[Unit]
Description=Odoo Service
After=network.target

[Service]
Type=simple
SyslogIdentifier=odoo
ExecStart=/usr/bin/python3 /odoo/odoo-bin -c /etc/odoo/odoo.conf
User=odoo
Group=odoo
WorkingDirectory=/odoo
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable odoo
systemctl start odoo

echo -e "\n---- Installation Complete ----"
echo "Your Odoo instance is running and ready!"

