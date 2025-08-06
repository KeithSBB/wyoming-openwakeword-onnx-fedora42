#!/bin/bash
set -e

# Install system dependencies
sudo dnf install -y python3 python3-pip alsa-utils

# Create wyoming user
sudo useradd -r -s /bin/false -d /usr/local/share/wyoming-openwakeword wyoming 2>/dev/null || true

# Create directories
sudo mkdir -p /usr/local/share/wyoming-openwakeword/{wyoming_openwakeword/models,script,.venv}
sudo cp -r wyoming_openwakeword/*.py /usr/local/share/wyoming-openwakeword/wyoming_openwakeword/
sudo cp -r wyoming_openwakeword/models/*.onnx /usr/local/share/wyoming-openwakeword/wyoming_openwakeword/models/ 2>/dev/null || true
sudo cp script/run /usr/local/share/wyoming-openwakeword/script/
sudo cp requirements.txt /usr/local/share/wyoming-openwakeword/

# Set permissions
sudo chown -R wyoming:wyoming /usr/local/share/wyoming-openwakeword
sudo chmod -R u+rwX,go+rX /usr/local/share/wyoming-openwakeword
sudo chmod +x /usr/local/share/wyoming-openwakeword/script/run

# Run setup script
sudo -u wyoming /bin/bash -c "cd /usr/local/share/wyoming-openwakeword && ./script/setup"

# Create systemd service
sudo bash -c 'cat << EOF > /etc/systemd/system/wyoming-openwakeword.service
[Unit]
Description=Wyoming OpenWakeWord Service
After=network.target

[Service]
User=wyoming
Group=wyoming
WorkingDirectory=/usr/local/share/wyoming-openwakeword
ExecStart=/usr/local/share/wyoming-openwakeword/script/run --uri tcp://0.0.0.0:10400
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

# Configure firewall
sudo firewall-cmd --add-port=10400/tcp --permanent
sudo firewall-cmd --reload

# Configure SELinux
sudo ausearch -m avc -ts recent | audit2allow -M wyoming 2>/dev/null || true
sudo semodule -i wyoming.pp 2>/dev/null || true
sudo setenforce 1

# Start service
sudo systemctl daemon-reload
sudo systemctl enable wyoming-openwakeword.service
sudo systemctl start wyoming-openwakeword.service