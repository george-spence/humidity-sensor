#!/bin/bash
set -e

# Download and install the Cloudflare One Client
function warp() {
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
    sudo apt-get update --assume-yes
    sudo apt-get install --assume-yes cloudflare-warp
}

# Create an MDM file with your Cloudflare One Client deployment parameters
function mdm() {
  sudo touch /var/lib/cloudflare-warp/mdm.xml
  cat > /var/lib/cloudflare-warp/mdm.xml << "EOF"
<dict>
    <key>auth_client_id</key>
    <string>EXAMPLE_CLIENT_ID</string>
    <key>auth_client_secret</key>
    <string>EXAMPLE_SECRET</string>
    <key>auto_connect</key>
    <integer>1</integer>
    <key>onboarding</key>
    <false/>
    <key>organization</key>
    <string>EXAMPLE_TEAM_NAME</string>
    <key>service_mode</key>
    <string>warp</string>
</dict>
EOF
}

#main program
warp
mdm