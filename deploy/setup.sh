#!/usr/bin/env bash

set -e

# Variables
PROJECT_NAME='profiles-rest-api'
PROJECT_GIT_URL='https://github.com/chingfo777/profiles-rest-api.git'
PROJECT_BASE_PATH="/usr/local/apps/$PROJECT_NAME"
VENV_PATH="$PROJECT_BASE_PATH/env"
DJANGO_SETTINGS_MODULE="$PROJECT_NAME.settings"

# Set Ubuntu Language
locale-gen en_GB.UTF-8

# Update and install necessary packages
echo "Updating package list and installing dependencies..."
sudo apt-get update
sudo apt-get install -y python3-dev python3-venv python3-pip nginx supervisor git tzdata

# Create project directory and clone the repository
echo "Creating project directory and cloning repository..."
sudo mkdir -p $PROJECT_BASE_PATH
sudo git clone $PROJECT_GIT_URL $PROJECT_BASE_PATH

# Set up virtual environment and install dependencies
echo "Setting up virtual environment and installing dependencies..."
python3 -m venv $VENV_PATH
source $VENV_PATH/bin/activate
pip install --upgrade pip
pip install uwsgi
pip install Django==3.2.25 djangorestframework==3.15.1 importlib-resources==5.4.0 pytz==2024.1 sqlparse==0.4.4 typing-extensions==4.1.1 zipp==3.6.0

# Run Django migrations
echo "Running Django migrations..."
cd $PROJECT_BASE_PATH
$VENV_PATH/bin/python manage.py migrate

# Collect static files
echo "Collecting static files..."
$VENV_PATH/bin/python manage.py collectstatic --noinput

# Set up Supervisor to run uWSGI
echo "Setting up Supervisor..."
sudo bash -c "cat > /etc/supervisor/conf.d/$PROJECT_NAME.conf" <<EOL
[program:$PROJECT_NAME]
command=$VENV_PATH/bin/uwsgi --ini $PROJECT_BASE_PATH/deploy/uwsgi.ini
directory=$PROJECT_BASE_PATH
autostart=true
autorestart=true
stderr_logfile=/var/log/$PROJECT_NAME.err.log
stdout_logfile=/var/log/$PROJECT_NAME.out.log
EOL

sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl restart $PROJECT_NAME

# Set up nginx to serve the Django application
echo "Setting up nginx..."
sudo bash -c "cat > /etc/nginx/sites-available/$PROJECT_NAME" <<EOL
server {
    listen 80;
    server_name your_domain_or_IP;

    location /static/ {
        alias $PROJECT_BASE_PATH/static/;
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

sudo ln -s /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled
sudo systemctl restart nginx

echo "Deployment completed successfully!"
