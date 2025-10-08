#!/bin/bash

# ---------------------------
# Paths
# ---------------------------
APP_DIR=/var/www/langchain-app
SOURCE_DIR=/home/ubuntu/myapp
VENV_DIR=/home/ubuntu/myapp_venv
SOCKET_FILE=$APP_DIR/myapp.sock   # Socket inside app directory, writable

# ---------------------------
# 1. Cleanup old app
# ---------------------------
echo "Deleting old app folder if exists..."
sudo rm -rf $APP_DIR

echo "Creating app folder..."
sudo mkdir -p $APP_DIR
sudo chown ubuntu:ubuntu $APP_DIR

echo "Moving files to app folder..."
sudo mv $SOURCE_DIR/* $APP_DIR/
sudo chown -R ubuntu:ubuntu $APP_DIR

# ---------------------------
# 2. Move .env if exists
# ---------------------------
if [ -f $APP_DIR/env ]; then
    mv $APP_DIR/env $APP_DIR/.env
fi

# ---------------------------
# 3. Install Python, pip, and venv
# ---------------------------
echo "Installing Python, pip, and venv..."
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv

# Remove old venv
rm -rf $VENV_DIR

echo "Creating virtual environment..."
python3 -m venv $VENV_DIR

# Upgrade pip and install dependencies
echo "Upgrading pip and installing dependencies..."
$VENV_DIR/bin/pip install --upgrade pip

if [ -f $APP_DIR/requirements.txt ]; then
    $VENV_DIR/bin/pip install -r $APP_DIR/requirements.txt
fi

# Always ensure Gunicorn + Uvicorn workers installed
$VENV_DIR/bin/pip install gunicorn uvicorn

# ---------------------------
# 4. Install & configure Nginx
# ---------------------------
if ! command -v nginx > /dev/null; then
    echo "Installing Nginx..."
    sudo apt-get install -y nginx
fi

if [ ! -f /etc/nginx/sites-available/myapp ]; then
    echo "Configuring Nginx..."
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo bash -c "cat > /etc/nginx/sites-available/myapp <<EOF
server {
    listen 80;
    server_name _;

    location / {
        include proxy_params;
        proxy_pass http://unix:$SOCKET_FILE;
    }
}
EOF"
    sudo ln -sf /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled
    sudo systemctl restart nginx
else
    echo "Nginx reverse proxy already configured."
fi

# ---------------------------
# 5. Stop old Gunicorn
# ---------------------------
pkill gunicorn || true
rm -f $SOCKET_FILE

# ---------------------------
# 6. Start Gunicorn with Uvicorn workers
# ---------------------------
echo "Starting Gunicorn with Uvicorn workers..."
cd $APP_DIR

$VENV_DIR/bin/gunicorn main:app \
    --workers 3 \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind unix:$SOCKET_FILE \
    --daemon

# ---------------------------
# 7. Set socket permissions for Nginx
# ---------------------------
echo "Setting socket permissions for Nginx..."
sudo chown www-data:www-data $SOCKET_FILE
sudo chmod 660 $SOCKET_FILE

echo "Gunicorn started 🚀"
echo "Deployment completed!"
echo "Visit your server's IP address to see the app."
