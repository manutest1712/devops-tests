#!/bin/bash
set -e

echo "===== Updating system ====="
apt-get update -y
apt-get install -y wget unzip python3 python3-pip python3-venv curl

echo "===== Installing Google Chrome ====="
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
apt-get install -y ./google-chrome-stable_current_amd64.deb

echo "===== Installing ChromeDriver (matching version) ====="
CHROME_VERSION=$(google-chrome --version | awk '{print $3}')
MAJOR_VERSION=$(echo "$CHROME_VERSION" | cut -d '.' -f 1)

# Use jq to safely parse the JSON for the version
DRIVER_VERSION=$(curl -s https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json | jq -r ".versions[] | select(.version | startswith(\"$MAJOR_VERSION.\")) | .version")

# Get the latest version from the remaining list (it should already be the latest)
DRIVER_VERSION=$(echo "$DRIVER_VERSION" | tail -n 1)

echo "Driver Version: $CHROME_VERSION"

wget -q "https://storage.googleapis.com/chrome-for-testing-public/$DRIVER_VERSION/linux64/chromedriver-linux64.zip"
unzip chromedriver-linux64.zip

echo "Moving Driver"
mv chromedriver-linux64/chromedriver /usr/local/bin/chromedriver
chmod +x /usr/local/bin/chromedriver

echo "===== Creating Python environment ====="
python3 -m venv /opt/selenium-env
/opt/selenium-env/bin/pip install --upgrade pip
/opt/selenium-env/bin/pip install selenium

echo "===== Done installing Selenium + ChromeDriver ====="
