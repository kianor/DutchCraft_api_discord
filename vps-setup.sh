#!/bin/bash
###############################################################################
# DutchCraft SMP - VPS Initial Setup Script
# Run this on a fresh Ubuntu/Debian VPS
###############################################################################

set -e  # Exit on error

echo "=================================="
echo "DutchCraft SMP - VPS Setup"
echo "=================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
   echo "❌ Please run as root: sudo bash vps-setup.sh"
   exit 1
fi

# Prompt for domain
read -p "Enter your API domain (e.g., api.dutchcraftsmp.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "❌ Domain cannot be empty!"
    exit 1
fi

echo ""
echo "📋 Setup Summary:"
echo "  - Domain: $DOMAIN"
echo "  - User: dutchcraft"
echo "  - App directory: /home/dutchcraft/dutchcraft-bot"
echo "  - Internal port: 3000"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

echo ""
echo "🚀 Starting installation..."
echo ""

# Update system
echo "📦 Updating system packages..."
apt update && apt upgrade -y

# Install Node.js 18.x
echo "📦 Installing Node.js 18.x..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Install other required packages
echo "📦 Installing Nginx, Certbot, Git..."
apt install -y nginx certbot python3-certbot-nginx git ufw

# Configure firewall
echo "🔒 Configuring firewall..."
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
echo "y" | ufw enable

# Create application user
echo "👤 Creating application user..."
if id "dutchcraft" &>/dev/null; then
    echo "  User 'dutchcraft' already exists"
else
    adduser --disabled-password --gecos "" dutchcraft
    echo "  User 'dutchcraft' created"
fi

# Create app directory
echo "📁 Creating application directory..."
mkdir -p /home/dutchcraft/dutchcraft-bot
chown dutchcraft:dutchcraft /home/dutchcraft/dutchcraft-bot

# Create Nginx configuration
echo "⚙️  Creating Nginx configuration..."
cat > /etc/nginx/sites-available/dutchcraft-api << EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Increase body size for file uploads
    client_max_body_size 10M;
}
EOF

# Enable Nginx site
ln -sf /etc/nginx/sites-available/dutchcraft-api /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and reload Nginx
nginx -t
systemctl enable nginx
systemctl restart nginx

# Create systemd service
echo "⚙️  Creating systemd service..."
cat > /etc/systemd/system/dutchcraft-bot.service << EOF
[Unit]
Description=DutchCraft SMP Discord Bot and API
After=network.target

[Service]
Type=simple
User=dutchcraft
WorkingDirectory=/home/dutchcraft/dutchcraft-bot
ExecStart=/usr/bin/node /home/dutchcraft/dutchcraft-bot/src/index.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=dutchcraft-bot

Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable dutchcraft-bot

echo ""
echo "✅ Base installation complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 NEXT STEPS:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. Upload your application files to:"
echo "   /home/dutchcraft/dutchcraft-bot/"
echo ""
echo "   From your local machine, run:"
echo "   scp -r /path/to/DutchCraft/* root@$(hostname -I | awk '{print $1}'):/home/dutchcraft/dutchcraft-bot/"
echo ""
echo "2. Create .env file with your configuration"
echo ""
echo "3. Install dependencies and deploy commands:"
echo "   su - dutchcraft"
echo "   cd ~/dutchcraft-bot"
echo "   npm install"
echo "   node deploy-commands.js"
echo "   exit"
echo ""
echo "4. Point your domain DNS to this server IP:"
echo "   IP: $(hostname -I | awk '{print $1}')"
echo "   DNS Record: A record for '$DOMAIN' → $(hostname -I | awk '{print $1}')"
echo ""
echo "5. Set up SSL certificate (after DNS is pointed):"
echo "   certbot --nginx -d $DOMAIN"
echo ""
echo "6. Start the service:"
echo "   systemctl start dutchcraft-bot"
echo "   systemctl status dutchcraft-bot"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔧 Useful commands:"
echo "  - View logs:      journalctl -u dutchcraft-bot -f"
echo "  - Restart bot:    systemctl restart dutchcraft-bot"
echo "  - Check status:   systemctl status dutchcraft-bot"
echo "  - Test Nginx:     nginx -t"
echo ""
echo "📖 See VPS-DEPLOYMENT-GUIDE.md for detailed instructions"
echo ""
