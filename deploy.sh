#!/bin/bash

APP_DIR=/var/www/langchain-app
SOURCE_DIR=/home/ubuntu/myapp
VENV_DIR=/home/ubuntu/myapp_venv

echo "Deleting old app folder if exists..."
sudo rm -rf $APP_DIR

echo "Creating app folder..."
sudo mkdir -p $APP_DIR

echo "Moving files to app folder..."
sudo mv $SOURCE_DIR/* $APP_DIR/

# Move .env file
if [ -f $APP_DIR/env ]; then
    mv $APP_DIR/env $APP_DIR/.env
fi

# Install python, pip, and venv if missing
echo "Installing python3, pip, and venv..."
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv

# Remove old venv if exists
rm -rf $VENV_DIR

# Create virtual environment in home directory (no sudo)
echo "Creating virtual environment..."
python3 -m venv $VENV_DIR

# Activate venv
source $VENV_DIR/bin/activate

# Upgrade pip and install dependencies
echo "Upgrading pip and installing dependencies..."
pip install --upgrade pip
if [ -f $APP_DIR/requirements.txt ]; then
    pip install -r $APP_DIR/requirements.txt
fi

# Install Gunicorn in venv
pip install gunicorn

# Install Nginx if missing
if ! command -v nginx > /dev/null; then
    echo "Installing Nginx..."
    sudo apt-get install -y nginx
fi

# Configure Nginx reverse proxy
if [ ! -f /etc/nginx/sites-available/myapp ]; then
    echo "Configuring Nginx..."
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo bash -c "cat > /etc/nginx/sites-available/myapp <<EOF
server {
    listen 80;
    server_name _;

    location / {
        include proxy_params;
        proxy_pass http://unix:$APP_DIR/myapp.sock;
    }
}
EOF"
    sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled
    sudo systemctl restart nginx
else
    echo "Nginx reverse proxy already configured."
fi

# Stop old Gunicorn
pkill gunicorn || true
rm -f $APP_DIR/myapp.sock

# Start Gunicorn from venv
echo "Starting Gunicorn..."
$VENV_DIR/bin/gunicorn --workers 3 --bind unix:$APP_DIR/myapp.sock main:app --user www-data --group www-data --daemon
echo "Gunicorn started 🚀"
echo "Deployment completed!"
