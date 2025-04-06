#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "TOR"
echo "  _____ _____     _____ _                                   "
echo " |_   _|  __ \\   / ____| |                                  "
echo "   | | | |__) | | |    | |__   __ _ _ __   __ _  ___ _ __   "
echo "   | | |  ___/  | |    |  _ \\ / _\` | '_ \\ / _\` |/ _ \\ '__|  "
echo "  _| |_| |      | |____| | | | (_| | | | | (_| |  __/ |     "
echo " |_____|_|       \\_____|_| |_|\\__,_|_| |_|\\__, |\\___|_|     "
echo "                                           __/ |            "
echo "                                          |___/     V 1.0   "
echo -e "${NC}"
echo -e "${YELLOW}Author: TechChip. https://www.youtube.com/@techchipnet ${NC}"
echo -e "${YELLOW}=========================================================${NC}\n"

set -e
[[ "$UID" -ne 0 ]] && {
    echo -e "${RED}❌ Please run this script as root.${NC}"
    exit 1
}

setup() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        echo -e "${RED}❌ Unsupported Linux distribution!${NC}"
        exit 1
    fi

    echo -e "${BLUE}[*] Detected Linux Distro: $DISTRO${NC}"

    echo -e "${BLUE}[*] Installing required packages (if not already installed)...${NC}"
    case "$DISTRO" in
        arch|manjaro|blackarch)
            sudo pacman -S --needed --noconfirm curl tor jq xxd
            TOR_GROUP="tor"
            ;;
        debian|ubuntu|kali|parrot)
            sudo apt update
            sudo apt install -y curl tor jq xxd
            TOR_GROUP="debian-tor"
            ;;
        fedora)
            sudo dnf install -y curl tor jq xxd
            TOR_GROUP="tor"
            ;;
        opensuse*)
            sudo zypper install -y curl tor jq xxd
            TOR_GROUP="tor"
            ;;
        *)
            echo -e "${RED}❌ Unsupported distro. Please install curl, tor, jq, xxd manually.${NC}"
            exit 1
            ;;
    esac

    if ! getent group "$TOR_GROUP" >/dev/null; then
        echo -e "${BLUE}[*] Group '$TOR_GROUP' not found, creating it...${NC}"
        sudo groupadd "$TOR_GROUP"
    fi

    if ! groups "$USER" | grep -q " $TOR_GROUP"; then
        echo -e "${BLUE}[*] Adding user '$USER' to group '$TOR_GROUP'...${NC}"
        sudo usermod -aG "$TOR_GROUP" "$USER"
    else
        echo -e "${GREEN}[✓] User '$USER' is already a member of group '$TOR_GROUP'.${NC}"
    fi


    echo -e "${BLUE}[*] Configuring Tor...${NC}"
    TORRC_FILE="/etc/tor/torrc"
    NEEDS_UPDATE=0

    grep -q "^ControlPort 9051" "$TORRC_FILE" || NEEDS_UPDATE=1
    grep -q "^CookieAuthentication 1" "$TORRC_FILE" || NEEDS_UPDATE=1
    grep -q "^CookieAuthFileGroupReadable 1" "$TORRC_FILE" || NEEDS_UPDATE=1

    if [ "$NEEDS_UPDATE" -eq 1 ]; then
        echo -e "${BLUE}[*] Updating torrc with required ControlPort settings...${NC}"
        {
            echo ""
            echo "# Added by change-tor-ip automation script"
            echo "ControlPort 9051"
            echo "CookieAuthentication 1"
            echo "CookieAuthFileGroupReadable 1"
        } | sudo tee -a "$TORRC_FILE" > /dev/null
        sudo systemctl restart tor
    else
        echo -e "${GREEN}[✓] torrc already configured correctly. Skipping update.${NC}"
    fi
}

ipchanger() {
    COOKIE=$(xxd -ps /var/run/tor/control.authcookie | tr -d '\n')

    printf 'AUTHENTICATE %s\r\nSIGNAL NEWNYM\r\nQUIT\r\n' "$COOKIE" | nc 127.0.0.1 9051 > /dev/null

    IP=$(curl -s --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip | jq -r .IP)
    echo "$(date '+%Y-%m-%d %H:%M:%S') - New Tor IP: $IP"
}

setup

read -p "Enter Tor IP change interval in seconds (default 10): " TIME_INTERVAL
TIME_INTERVAL=${TIME_INTERVAL:-10}

echo -e "${GREEN}[*] Starting Tor IP changer every $TIME_INTERVAL seconds...${NC}"

while true; do
    ipchanger
    sleep "$TIME_INTERVAL"
done
