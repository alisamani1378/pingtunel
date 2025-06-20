#!/bin/bash

# --- Step 1: Configuration and Prerequisite Checks ---

# --- !!! CONFIGURATION REQUIRED !!! ---
# Please replace the <YOUR_IRAN_MIRROR_IP> placeholder below with the IP of your mirror server in Iran before using.
IRAN_MIRROR_URL="http://193.151.151.78:8000/pingtunnel"
# --- !!! END OF CONFIGURATION !!! ---

# Public download link from GitHub
GITHUB_URL="https://raw.githubusercontent.com/alisamani1378/pingtunel/main/pingtunnel"

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Please run this script with root privileges or using sudo."
  exit 1
fi

# --- Step 2: Auto-Select Download URL and Download Binary ---
# (This part is unchanged)
DOWNLOAD_URL=""
echo "--> Checking network connectivity to select download source..."
if ping -c 1 -W 5 raw.githubusercontent.com &> /dev/null; then
    echo "--> GitHub is reachable. Using public download link."
    DOWNLOAD_URL="$GITHUB_URL"
else
    echo "--> GitHub is not reachable. Using Iran mirror link."
    if [[ "$IRAN_MIRROR_URL" == *"YOUR_IRAN_MIRROR_IP"* ]]; then
        echo ""
        echo "FATAL: The Iran mirror URL is not configured in the script."
        echo "Please edit the 'setup.sh' file and set the 'IRAN_MIRROR_URL' variable."
        exit 1
    fi
    DOWNLOAD_URL="$IRAN_MIRROR_URL"
fi
echo "--> Starting download from: ${DOWNLOAD_URL}"
mkdir -p /tmp/pt_setup
cd /tmp/pt_setup
if ! curl -Lso pingtunnel "${DOWNLOAD_URL}"; then
    echo "FATAL: Failed to download 'pingtunnel'. Please check the URL and your network."
    exit 1
fi
echo "Download successful."
chmod +x ./pingtunnel
mv ./pingtunnel /root/pingtunnel
echo "Moved 'pingtunnel' binary to /root/pingtunnel"

# --- Step 3: Interactive Setup with a Numbered Menu ---
echo ""
echo "Please select the installation type:"
echo "   1) Setup as Server (for the machine outside Iran)"
echo "   2) Setup as Client (for the machine inside Iran)"
echo ""
read -p "Enter your choice [1-2]: " choice

case "$choice" in
    1)
        # --- Server Setup Logic ---
        echo "Configuring as PingTunnel Server..."
        cat > /etc/systemd/system/pingtunnel-server.service << EOL
[Unit]
Description=Pingtunnel Server Service
After=network.target
[Service]
ExecStart=/root/pingtunnel -type server -key 1378
Restart=always
RestartSec=5
User=root
[Install]
WantedBy=multi-user.target
EOL
        systemctl daemon-reload
        systemctl enable pingtunnel-server
        systemctl start pingtunnel-server
        echo "PingTunnel server service has been started and enabled."
        echo "To check the status, run: systemctl status pingtunnel-server"
        ;;

    2)
        # --- Client Setup Logic with PING CHECK and AUTO-MONITORING ---
        echo "Configuring as PingTunnel Client..."
        read -p "Enter the public IP of your OUTSIDE server: " SERVER_IP
        echo ""
        echo "--> Testing connectivity to ${SERVER_IP} with 4 pings..."
        if ping -c 4 -W 5 ${SERVER_IP}; then
            echo "--> Ping successful. Proceeding with installation..."
            echo ""
        else
            echo ""
            echo "--> FATAL: Could not ping the server at ${SERVER_IP}."
            echo "--> Please check the IP address and network, then try again."
            rm -rf /tmp/pt_setup
            exit 1
        fi
        read -p "Enter a local port for this client to listen on (e.g., 5688): " LOCAL_PORT

        # Create and start the pingtunnel client service
        cat > /etc/systemd/system/pingtunnel-client.service << EOL
[Unit]
Description=Pingtunnel Client Service
After=network.target
[Service]
ExecStart=/root/pingtunnel -type client -l :${LOCAL_PORT} -s ${SERVER_IP} -t ${SERVER_IP}:443 -tcp 1 -key 1378
Restart=always
RestartSec=5
User=root
[Install]
WantedBy=multi-user.target
EOL
        systemctl daemon-reload
        systemctl enable pingtunnel-client
        systemctl start pingtunnel-client
        echo "--> PingTunnel client service has been started and enabled."
        
        # --- NEW: Automatic Monitoring Setup ---
        echo ""
        read -p "Do you want to set up automatic health-check and alerts? (y/n): " setup_monitor
        if [[ "$setup_monitor" == "y" || "$setup_monitor" == "Y" ]]; then
            echo "--> Setting up monitoring..."
            read -p "Enter your ntfy.sh topic for alerts: " NTFY_TOPIC

            if [ -z "$NTFY_TOPIC" ]; then
                echo "--> WARNING: ntfy.sh topic is empty. Skipping monitoring setup."
            else
                # Create the health_check.sh script using a Here Document
                # Note the unquoted EOF to allow variable expansion for $SERVER_IP and $NTFY_TOPIC
                cat << EOF > /root/health_check.sh
#!/bin/bash
# This script was generated automatically by the setup script.

# --- Configuration ---
OUTSIDE_SERVER_IP="${SERVER_IP}"
NTFY_TOPIC="${NTFY_TOPIC}"
FAILURE_FLAG_FILE="/tmp/ping_failed_once"

# --- Functions ---
send_alert() {
    local message="\$1"
    # Get the current IP of this server
    IRAN_SERVER_IP=\$(curl -s --ipv4 ifconfig.me)
    # Replace placeholders in the message
    message=\$(echo "\$message" | sed "s/IRAN_IP/\$IRAN_SERVER_IP/g")
    curl -s -H "Title: Tunnel Alert" -d "\$message" "https://ntfy.sh/\${NTFY_TOPIC}" > /dev/null
}

# --- Main Logic ---
if ping -c 4 -W 2 "\$OUTSIDE_SERVER_IP" &> /dev/null; then
    if [ -f "\$FAILURE_FLAG_FILE" ]; then
        ALERT_MESSAGE="✅ Connection Restored: Iran Server (IRAN_IP) is now connected to Outside Server (\${OUTSIDE_SERVER_IP})."
        send_alert "\$ALERT_MESSAGE"
        rm "\$FAILURE_FLAG_FILE"
    fi
else
    if [ -f "\$FAILURE_FLAG_FILE" ]; then
        ALERT_MESSAGE="🚨 CRITICAL FAILURE: Connection lost from Iran Server (IRAN_IP) to Outside Server (\${OUTSIDE_SERVER_IP}). Tunnel service stopped."
        send_alert "\$ALERT_MESSAGE"
        systemctl stop pingtunnel-client.service
        rm "\$FAILURE_FLAG_FILE"
    else
        touch "\$FAILURE_FLAG_FILE"
    fi
fi
EOF
                # Make the script executable
                chmod +x /root/health_check.sh
                echo "--> Monitoring script created at /root/health_check.sh"

                # Create the cron job file for automatic execution
                # This is safer than editing the user's crontab directly
                cat << EOF > /etc/cron.d/tunnel_monitor
# This file was generated automatically by the setup script.
# It runs the tunnel health check every 5 minutes.
*/5 * * * * root /root/health_check.sh >> /var/log/health_check.log 2>&1
EOF
                echo "--> Cron job created at /etc/cron.d/tunnel_monitor"
                echo "--> Monitoring setup is complete."
            fi
        fi
        # --- END of Automatic Monitoring Setup ---
        ;;

    *)
        # --- Invalid Input ---
        echo "Invalid input. Please run the script again and enter 1 or 2."
        rm -rf /tmp/pt_setup
        exit 1
        ;;
esac

# Cleanup
rm -rf /tmp/pt_setup
echo "Setup finished and temporary files removed."
