#!/bin/bash

APP_DIR=/var/www/langchain-app
SOURCE_DIR=/home/ubuntu/myapp

echo "Deleting old app folder if exists..."
sudo rm -rf $APP_DIR

echo "Creating app folder..."
sudo mkdir -p $APP_DIR

echo "Moving files to app folder..."
sudo mv $SOURCE_DIR/* $APP_DIR/

# Navigate to the app directory
cd $APP_DIR

# Move .env file if exists
if [ -f env ]; then
    mv env .env
fi

# Install Python, pip, and venv if missing
echo "Installing python3, pip, and venv..."
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv

# Create virtual environment if not exists
if [ ! -d venv ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Upgrade pip and install Python dependencies
echo "Upgrading pip and installing dependencies..."
pip install --upgrade pip
if [ -f requirements.txt ]; then
    pip install -r requirements.txt
fi

# Install Gunicorn inside venv
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

# Stop any running Gunicorn process
pkill gunicorn || true
rm -f myapp.sock

# Start Gunicorn using venv (without sudo)
echo "Starting Gunicorn..."
venv/bin/gunicorn --workers 3 --bind unix:myapp.sock main:app --user www-data --group www-data --daemon
echo "Gunicorn started 🚀"
echo "Deployment completed!"
