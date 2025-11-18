#!/bin/bash

CONFIG_FILE="/etc/mirza-bot/script.conf"
SCRIPT_PATH=$(realpath "$0")

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
    clear
    echo -e "${GREEN}############################################################${NC}"
    echo -e "${GREEN}##                                                        ##${NC}"
    echo -e "${GREEN} ##                  Mirza Pro Bot                       ##${NC}"
    echo -e "${GREEN}  ##            Automated Management Script             ##${NC}"
    echo -e "${GREEN}   ##                                                  ##${NC}"
    echo -e "${GREEN}  ##     Installer by @H_ExPLoSiVe (ExPLoSiVe1988)      ##${NC}"
    echo -e "${GREEN} ##     Based on the original project by mahdiMGF2       ##${NC}"
    echo -e "${GREEN}##                                                        ##${NC}"
    echo -e "${GREEN}############################################################${NC}"
    echo ""
}

save_config() {
    mkdir -p /etc/mirza-bot
    echo "DOMAIN=$1" > "$CONFIG_FILE"
    echo "BOT_TOKEN=$2" >> "$CONFIG_FILE"
    echo "ADMIN_TELEGRAM_ID=$3" >> "$CONFIG_FILE"
    echo "BACKUP_CHAT_ID=$4" >> "$CONFIG_FILE"
    echo "DB_PASSWORD=$5" >> "$CONFIG_FILE"
    echo "DB_NAME=$6" >> "$CONFIG_FILE"
    echo "DB_USER=$7" >> "$CONFIG_FILE"
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        return 0
    else
        echo -e "${RED}Error: Configuration file not found.${NC}"
        return 1
    fi
}

check_apache() {
    if ! systemctl is-active --quiet apache2; then
        echo -e "\n${RED}=====================================================${NC}"
        echo -e "${RED}Error: Apache service failed to start. Aborting.${NC}"
        echo -e "${YELLOW}--- Displaying Apache Status ---${NC}"
        systemctl status apache2 --no-pager
        echo -e "\n${YELLOW}--- Displaying Last Journal Entries for Apache ---${NC}"
        journalctl -xeu apache2.service --no-pager | tail -n 20
        echo -e "${RED}=====================================================${NC}"
        exit 1
    fi
}

############################################################
# CORE FUNCTIONS
############################################################

install_bot() {
    print_header
    echo -e "${YELLOW}Starting Mirza Pro Bot Installation...${NC}"

    echo "--- Basic Information ---"
    read -p "Enter your domain (e.g., bot.yourdomain.com): " DOMAIN
    read -p "Enter your email for SSL notifications: " SSL_EMAIL
    echo -e "\n--- Database Settings ---"
    read -p "Enter a name for the database (e.g., mirza_db): " DB_NAME
    read -p "Enter a username for the database (e.g., mirza_user): " DB_USER
    SUGGESTED_DB_PASSWORD=$(openssl rand -base64 18)
    read -p "Enter a database password or press Enter to use this secure one [$SUGGESTED_DB_PASSWORD]: " USER_DB_PASSWORD
    DB_PASSWORD=${USER_DB_PASSWORD:-$SUGGESTED_DB_PASSWORD}
    echo -e "\n--- Telegram Bot Settings ---"
    read -p "Enter your Telegram Bot Token: " BOT_TOKEN
    read -p "Enter your numeric Telegram Admin ID: " ADMIN_TELEGRAM_ID
    read -p "Enter your Telegram Bot Username (without @): " BOT_USERNAME
    echo -e "\n${YELLOW}--- Backup Configuration ---${NC}"
    read -p "Enter the private channel/group Chat ID for backups (optional, defaults to your admin account): " BACKUP_CHAT_ID
    if [ -z "$BACKUP_CHAT_ID" ]; then
        BACKUP_CHAT_ID=$ADMIN_TELEGRAM_ID
    fi
    echo -e "\n--- Panel Compatibility ---"
    read -p "Are you using the NEW Marzban panel? (yes/no): " MARZBAN_CHOICE

    echo -e "\n${BLUE}Starting automatic installation... This may take a few minutes.${NC}"

    echo -e "${BLUE}Step 1: Hardening Environment (Aggressive Cleanup)...${NC}"
    systemctl stop apache2 >/dev/null 2>&1
    rm -f /etc/apache2/sites-available/mirza-pro.conf /etc/apache2/sites-enabled/mirza-pro.conf
    rm -f /etc/apache2/sites-available/mirza-pro-le-ssl.conf /etc/apache2/sites-enabled/mirza-pro-le-ssl.conf
    certbot delete --cert-name "$DOMAIN" --non-interactive > /dev/null 2>&1
    systemctl start apache2 >/dev/null 2>&1

    echo -e "${BLUE}Step 2: System Update & Dependencies...${NC}"
    apt-get update > /dev/null 2>&1
    apt-get install -y ufw apache2 mysql-server git software-properties-common certbot python3-certbot-apache > /dev/null 2>&1
    add-apt-repository ppa:ondrej/php -y > /dev/null 2>&1
    apt-get update > /dev/null 2>&1
    apt-get install -y php8.2 libapache2-mod-php8.2 php8.2-cli php8.2-common php8.2-mbstring php8.2-curl php8.2-xml php8.2-zip php8.2-mysql php8.2-gd php8.2-bcmath > /dev/null 2>&1
    
    echo -e "${BLUE}Step 3: Database Setup...${NC}"
    mysql -u root <<MYSQL_SCRIPT
DROP DATABASE IF EXISTS \`$DB_NAME\`;
DROP USER IF EXISTS '$DB_USER'@'localhost';
CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

    echo -e "${BLUE}Step 4: Downloading Source Code...${NC}"
    rm -rf /var/www/mirza_pro
    git clone https://github.com/ExPLoSiVe1988/Mirza-Pro.git /var/www/mirza_pro > /dev/null 2>&1
    chown -R www-data:www-data /var/www/mirza_pro

    echo -e "${BLUE}Step 5: Generating config.php...${NC}"
    cat > /var/www/mirza_pro/config.php <<'EOF'
<?php
$dbname = '{database_name}';
$usernamedb = '{username_db}';
$passworddb = '{password_db}';
$connect = mysqli_connect("localhost", $usernamedb, $passworddb, $dbname);
if ($connect->connect_error) { die("error" . $connect->connect_error); }
mysqli_set_charset($connect, "utf8mb4");
$options = [ PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC, PDO::ATTR_EMULATE_PREPARES => false, ];
$dsn = "mysql:host=localhost;dbname=$dbname;charset=utf8mb4";
try { $pdo = new PDO($dsn, $usernamedb, $passworddb, $options); } catch (\PDOException $e) { die("DATABASE ERROR: " . $e->getMessage()); }
$APIKEY = '{API_KEY}';
$adminnumber = '{admin_number}';
$domainhosts = '{domain_name}';
$usernamebot = '{username_bot}';
?>
EOF

    if [[ "$MARZBAN_CHOICE" =~ ^[yY] ]]; then
        echo '$new_marzban = true;' >> /var/www/mirza_pro/config.php
    fi
    
    sed -i "s|{database_name}|$DB_NAME|g" /var/www/mirza_pro/config.php
    sed -i "s|{username_db}|$DB_USER|g" /var/www/mirza_pro/config.php
    sed -i "s|{password_db}|$DB_PASSWORD|g" /var/www/mirza_pro/config.php
    sed -i "s|{API_KEY}|$BOT_TOKEN|g" /var/www/mirza_pro/config.php
    sed -i "s|{admin_number}|$ADMIN_TELEGRAM_ID|g" /var/www/mirza_pro/config.php
    sed -i "s|{domain_name}|http://$DOMAIN|g" /var/www/mirza_pro/config.php
    sed -i "s|{username_bot}|$BOT_USERNAME|g" /var/www/mirza_pro/config.php

    echo -e "${BLUE}Step 6: Creating Database Tables...${NC}"
    cd /var/www/mirza_pro
    php table.php
    mv table.php table.php.installed

    echo -e "${BLUE}Step 7: Configure Apache for HTTP...${NC}"
    ufw allow ssh > /dev/null; ufw allow 'Apache Full' > /dev/null; ufw --force enable > /dev/null
    a2dismod php7.4 php8.0 php8.1 2>/dev/null; a2enmod php8.2 rewrite > /dev/null
    cat > /etc/apache2/sites-available/mirza-pro.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot /var/www/mirza_pro
    <Directory /var/www/mirza_pro>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
    a2dissite 000-default.conf > /dev/null 2>&1
    a2ensite mirza-pro.conf > /dev/null
    systemctl restart apache2
    check_apache

    echo -e "${BLUE}Step 8: Obtaining SSL Certificate (HTTPS)...${NC}"
    certbot --apache --non-interactive --agree-tos --redirect -d "$DOMAIN" -m "$SSL_EMAIL"
    check_apache
    
    sed -i "s|http://$DOMAIN|https://$DOMAIN|g" /var/www/mirza_pro/config.php
    
    echo -e "${BLUE}Step 9: Finalizing Setup...${NC}"
    curl -s "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook?url=https://${DOMAIN}/index.php"
    mysql -u root <<MYSQL_SCRIPT
USE \`$DB_NAME\`;
UPDATE admin SET id_admin = '$ADMIN_TELEGRAM_ID';
MYSQL_SCRIPT
    (crontab -l 2>/dev/null | grep -v "/var/www/mirza_pro/cronbot/") | crontab -
    CRON_JOBS="* * * * * php /var/www/mirza_pro/cronbot/NoticationsService.php >/dev/null 2>&1
*/5 * * * * php /var/www/mirza_pro/cronbot/uptime_panel.php >/dev/null 2>&1
*/5 * * * * php /var/www/mirza_pro/cronbot/uptime_node.php >/dev/null 2>&1
*/10 * * * * php /var/www/mirza_pro/cronbot/expireagent.php >/dev/null 2>&1
*/10 * * * * php /var/www/mirza_pro/cronbot/payment_expire.php >/dev/null 2>&1
0 * * * * php /var/www/mirza_pro/cronbot/statusday.php >/dev/null 2>&1
0 3 * * * php /var/www/mirza_pro/cronbot/backupbot.php >/dev/null 2>&1
*/15 * * * * php /var/www/mirza_pro/cronbot/iranpay1.php >/dev/null 2>&1
*/15 * * * * php /var/www/mirza_pro/cronbot/plisio.php >/dev/null 2>&1"
    (crontab -l 2>/dev/null; echo "$CRON_JOBS") | crontab -

    save_config "$DOMAIN" "$BOT_TOKEN" "$ADMIN_TELEGRAM_ID" "$BACKUP_CHAT_ID" "$DB_PASSWORD" "$DB_NAME" "$DB_USER"
    echo -e "\n${GREEN}Installation Complete! You can now use the bot.${NC}"
}

uninstall_bot() {
    print_header
    local DOMAIN_TO_UNINSTALL
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        DOMAIN_TO_UNINSTALL=$DOMAIN
    else
        read -p "Configuration file not found. Please enter the domain you want to uninstall: " DOMAIN_TO_UNINSTALL
        if [ -z "$DOMAIN_TO_UNINSTALL" ]; then echo "Domain cannot be empty. Aborting."; return; fi
    fi
    
    read -p "Are you sure? This will delete all files and database for the bot on domain '$DOMAIN_TO_UNINSTALL'. (yes/no): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then echo "Cancelled."; return; fi

    echo -e "${YELLOW}Uninstalling... (This will remove all traces)${NC}"
    (crontab -l 2>/dev/null | grep -v "/var/www/mirza_pro/\|backup_now") | crontab -
    
    systemctl stop apache2 >/dev/null 2>&1
    
    a2dissite mirza-pro.conf > /dev/null 2>&1
    a2dissite mirza-pro-le-ssl.conf > /dev/null 2>&1
    rm -f /etc/apache2/sites-available/mirza-pro.conf /etc/apache2/sites-enabled/mirza-pro.conf
    rm -f /etc/apache2/sites-available/mirza-pro-le-ssl.conf /etc/apache2/sites-enabled/mirza-pro-le-ssl.conf

    certbot delete --cert-name "$DOMAIN_TO_UNINSTALL" --non-interactive > /dev/null 2>&1
    
    if [ -f "$CONFIG_FILE" ]; then
        mysql -u root <<MYSQL_SCRIPT
DROP DATABASE IF EXISTS \`$DB_NAME\`;
DROP USER IF EXISTS '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
    fi
    
    rm -rf /var/www/mirza_pro /etc/mirza-bot
    
    systemctl start apache2 >/dev/null 2>&1
    echo -e "${GREEN}Uninstallation complete.${NC}"
}

############################################################
# BACKUP FUNCTIONS
############################################################

run_db_backup() {
    echo -e "${YELLOW}Starting Database Backup...${NC}"
    if ! load_config; then return; fi

    DB_BACKUP_FILE="/tmp/${DB_NAME}_$(date +%Y%m%d_%H%M%S).sql"
    
    echo "1. Dumping database..."
    mysqldump --no-tablespaces -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" > "$DB_BACKUP_FILE"
    
    if [ $? -ne 0 ] || [ ! -s "$DB_BACKUP_FILE" ]; then 
        echo -e "${RED}FATAL: Failed to create a valid database dump.${NC}"
        echo -e "${YELLOW}Please check the error message above. Common causes are incorrect DB credentials or permissions.${NC}"
        rm -f "$DB_BACKUP_FILE"
        return
    fi
    echo -e "${GREEN}Database dump created successfully.${NC}"

    echo -e "\n2. Sending to Telegram..."
    API_URL="https://api.telegram.org/bot${BOT_TOKEN}/sendDocument"
    CAPTION=$(cat <<EOF

  
<b>Mirza Pro Bot: Database Backup</b>

💾 <b>Type:</b> Database (.sql)
🌐 <b>Domain:</b> <code>$DOMAIN</code>
📅 <b>Timestamp:</b> <code>$(date +'%Y-%m-%d %H:%M:%S %Z')</code>
EOF
)
    echo "DEBUG: Attempting to send to Chat ID -> [$BACKUP_CHAT_ID]"
    RESPONSE=$(curl --verbose -F "chat_id=${BACKUP_CHAT_ID}" -F "document=@${DB_BACKUP_FILE}" -F "caption=${CAPTION}" -F "parse_mode=HTML" "$API_URL")
    
    echo -e "\n${YELLOW}--- Full cURL & Telegram API Response ---${NC}"
    echo "$RESPONSE"
    echo -e "${YELLOW}-----------------------------------------${NC}"

    if [[ $(echo "$RESPONSE" | grep -c '"ok":true') -gt 0 ]]; then
        echo -e "${GREEN}DB backup sent successfully.${NC}"
    else
        echo -e "${RED}Failed to send DB backup. Please review the full response above.${NC}"
    fi
    
    echo "3. Cleaning up..."
    rm -f "$DB_BACKUP_FILE"
}

run_files_backup() {
    echo -e "${YELLOW}Starting Source Files Backup...${NC}"
    if ! load_config; then return; fi

    local BACKUP_DIR="/tmp"
    local FILES_BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_$(date +%Y%m%d_%H%M%S).tar.gz"
    local MAX_FILE_SIZE_BYTES=50000000
    local SPLIT_SIZE_BYTES=45000000

    echo "1. Creating file archive in: ${FILES_BACKUP_FILE}"
    tar -czf "$FILES_BACKUP_FILE" -C /var/www mirza_pro

    if [ ! -f "$FILES_BACKUP_FILE" ] || [ ! -s "$FILES_BACKUP_FILE" ]; then
        echo -e "${RED}FATAL: Failed to create archive.${NC}"
        rm -f "$FILES_BACKUP_FILE"
        return
    fi
    echo -e "${GREEN}File archive created successfully.${NC}"

    local BASE_CAPTION=$(cat <<EOF
<b>Mirza Pro Bot: Files Backup</b>
📦 <b>Type:</b> Source Files (.tar.gz)
🌐 <b>Domain:</b> <code>$DOMAIN</code>
📅 <b>Timestamp:</b> <code>$(date +'%Y-%m-%d %H:%M:%S %Z')</code>
EOF
)

    local FILE_SIZE
    FILE_SIZE=$(stat -c%s "$FILES_BACKUP_FILE")

    echo -e "\n2. Sending to Telegram..."

    local API_URL="https://api.telegram.org/bot${BOT_TOKEN}/sendDocument"

    if [ "$FILE_SIZE" -le "$MAX_FILE_SIZE_BYTES" ]; then
        RESPONSE=$(curl -s -X POST "$API_URL" \
            -F chat_id="$BACKUP_CHAT_ID" \
            -F document=@"$FILES_BACKUP_FILE" \
            --form-string "caption=$BASE_CAPTION" \
            -F parse_mode="HTML")
    else
        echo -e "${YELLOW}File size $(echo "scale=2; $FILE_SIZE/1024/1024" | bc)MB > 50MB, splitting...${NC}"
        split -b $SPLIT_SIZE_BYTES -d -a 3 "$FILES_BACKUP_FILE" "${FILES_BACKUP_FILE}.part_"
        for PART in ${FILES_BACKUP_FILE}.part_*; do
            local PART_NUM=$(basename "$PART" | awk -F'_part_' '{print $2}')
            local CAPTION="$BASE_CAPTION\n<b>Part:</b> $PART_NUM"
            RESPONSE=$(curl -s -X POST "$API_URL" \
                -F chat_id="$BACKUP_CHAT_ID" \
                -F document=@"$PART" \
                --form-string "caption=$CAPTION" \
                -F parse_mode="HTML")
            if echo "$RESPONSE" | grep -q '"ok":true'; then
                echo -e "${GREEN}Part $PART_NUM sent successfully.${NC}"
            else
                echo -e "${RED}Failed to send Part $PART_NUM. Check response below:${NC}"
                echo "$RESPONSE"
            fi
        done
    fi

    rm -f "$FILES_BACKUP_FILE" ${FILES_BACKUP_FILE}.part_*

    echo -e "${GREEN}Backup process completed.${NC}"
}

configure_backup_schedule() {
    local backup_type=$1
    local cron_job_name="backup_$backup_type"
    
    print_header
    echo -e "${YELLOW}Configure schedule for ${backup_type^^} backup:${NC}"
    echo " 1. Every 2 minutes (For DB testing)"
    echo " 2. Every hour"
    echo " 3. Every 6 hours"
    echo " 4. Daily (at 3:00 AM)"
    echo " 5. Weekly (on Sundays)"
    echo " 6. Custom Interval (in minutes)"
    echo " 7. Disable for ${backup_type^^}"
    read -p "Enter your choice [1-7]: " cron_choice

    (crontab -l 2>/dev/null | grep -v "$cron_job_name") | crontab -
    CRON_COMMAND="$SCRIPT_PATH $cron_job_name >/dev/null 2>&1"
    CRON_SCHEDULE=""
    MSG=""

    case $cron_choice in
        1) CRON_SCHEDULE="*/2 * * * *"; MSG="Every 2 minutes" ;;
        2) CRON_SCHEDULE="0 * * * *"; MSG="Hourly" ;;
        3) CRON_SCHEDULE="0 */6 * * *"; MSG="Every 6 hours" ;;
        4) CRON_SCHEDULE="0 3 * * *"; MSG="Daily" ;;
        5) CRON_SCHEDULE="0 3 * * 0"; MSG="Weekly" ;;
        6) 
            read -p "Enter interval in minutes: " INTERVAL
            if [[ ! $INTERVAL =~ ^[0-9]+$ ]] || [[ $INTERVAL -eq 0 ]]; then echo -e "${RED}Invalid.${NC}"; return; fi
            CRON_SCHEDULE="*/$INTERVAL * * * *"; MSG="Every $INTERVAL minutes"
            ;;
        7) echo -e "${YELLOW}Automatic ${backup_type^^} backups disabled.${NC}"; return ;;
        *) echo -e "${RED}Invalid option.${NC}"; return ;;
    esac

    (crontab -l 2>/dev/null; echo "$CRON_SCHEDULE $CRON_COMMAND") | crontab -
    echo -e "${GREEN}Automatic ${backup_type^^} backup schedule set: $MSG${NC}"
}

backup_menu() {
    while true; do
        print_header
        if ! load_config; then read -p "Press Enter to return..."; return; fi
        echo -e "Backup Destination Chat ID: ${YELLOW}$BACKUP_CHAT_ID${NC}"
        echo "-----------------------------------------------------"
        echo " 1. Run Manual Database Backup (.sql)"
        echo " 2. Run Manual Source Files Backup (.tar.gz)"
        echo " 3. Configure Auto DB Backup"
        echo " 4. Configure Auto Files Backup"
        echo " 5. Change Backup Destination"
        echo " 6. Back to Main Menu"
        read -p "Enter your choice [1-6]: " choice

        case $choice in
            1) run_db_backup; read -p "Press Enter..." ;;
            2) run_files_backup; read -p "Press Enter..." ;;
            3) configure_backup_schedule "db"; read -p "Press Enter..." ;;
            4) configure_backup_schedule "files"; read -p "Press Enter..." ;;
            5)
                read -p "Enter new Backup Chat ID: " NEW_ID
                if [[ -n "$NEW_ID" ]]; then
                    sed -i "s/^BACKUP_CHAT_ID=.*/BACKUP_CHAT_ID=$NEW_ID/" "$CONFIG_FILE"
                    echo -e "${GREEN}Destination updated.${NC}"
                fi
                read -p "Press Enter..."
                ;;
            6) return ;;
            *) echo -e "${RED}Invalid option.${NC}"; read -p "Press Enter..." ;;
        esac
    done
}

############################################################
# MAIN MENU
############################################################

show_menu() {
    print_header
    echo "Select an option from the menu:"
    echo -e " ${GREEN}1.${NC} Install / Re-install Bot"
    echo -e " ${YELLOW}2.${NC} Backup Management"
    echo -e " ${BLUE}3.${NC} Renew SSL Certificate"
    echo -e " ${RED}4.${NC} Uninstall Bot"
    echo -e " ${NC}5. Exit"
    echo ""
    read -p "Enter your choice [1-5]: " choice
    
    case $choice in
        1) install_bot ;;
        2) backup_menu ;;
        3) echo "Renewing SSL..."; certbot renew; echo "Done." ;;
        4) uninstall_bot ;;
        5) exit 0 ;;
        *) echo -e "${RED}Invalid option.${NC}" ;;
    esac
    read -p "Press Enter to return to the menu..."
    show_menu
}

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run as root.${NC}"
  exit 1
fi

case "$1" in
    backup_db)
        run_db_backup
        exit 0
        ;;
    backup_files)
        run_files_backup
        exit 0
        ;;
esac


show_menu
