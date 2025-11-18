#!/bin/bash
set -e

# Configuration variables passed from Terraform
ADO_URL="${ADO_URL}"
PAT_TOKEN="${PAT_TOKEN}"
POOL_NAME="${POOL_NAME}"
ADMIN_USER="${ADMIN_USER}"
VM_NAME="${VM_NAME}"
AGENT_FILE="${AGENT_FILE}"
AGENT_URL="${AGENT_URL}"

echo "Starting Azure DevOps Agent installation and configuration..."

# 1. Update and install dependencies
sudo apt-get update -y

# --- Agent Installation ---

AGENT_DIR="/home/${ADMIN_USER}/myagent"

# 2. Download the agent (using -L to follow redirects)
echo "Downloading agent version ${AGENT_FILE}..."
curl -L -o /tmp/${AGENT_FILE} ${AGENT_URL}

# 3. Create directory and extract
echo "Extracting agent to $${AGENT_DIR}..."
mkdir -p $${AGENT_DIR}
tar zxvf /tmp/${AGENT_FILE} -C $${AGENT_DIR}
chown -R ${ADMIN_USER}:${ADMIN_USER} $${AGENT_DIR}

# 4. Configure the agent (NON-INTERACTIVE)
# The config.sh must be run by the admin user, not root (sudo), 
# so we switch user using 'su'
echo "Configuring agent for ${POOL_NAME} pool on ${ADO_URL}..."
su - ${ADMIN_USER} -c "
  cd $${AGENT_DIR} && \
  ./config.sh --unattended \
    --url \"${ADO_URL}\" \
    --auth pat \
    --token \"${PAT_TOKEN}\" \
    --pool \"${POOL_NAME}\" \
    --agent \"${VM_NAME}\" \
    --work \"_work\" \
    --replace \
    --acceptTfvcEula \
    --runasservice
"

# 5. Install and start the service (using sudo/root)
echo "Installing and starting agent service..."
cd $${AGENT_DIR}
echo $${AGENT_DIR}
sudo ./svc.sh install
sudo ./svc.sh start

# 6. Cleanup
echo "Cleaning up..."
rm -f /tmp/${AGENT_FILE}

echo "Azure DevOps Agent installation complete."


# 7. --- Install Java (JDK 11) ---
echo "Installing Java..."
sudo apt-get install -y openjdk-11-jdk
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
echo "JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" | sudo tee -a /etc/environment
echo "PATH=$JAVA_HOME/bin:$PATH" | sudo tee -a /etc/environment

# 8. --- Install JMeter ---
echo "Installing JMeter 5.6.3..."
JMETER_VERSION="5.6.3"
cd /opt
sudo wget https://downloads.apache.org/jmeter/binaries/apache-jmeter-$${JMETER_VERSION}.tgz
sudo tar -xf apache-jmeter-$${JMETER_VERSION}.tgz
sudo mv apache-jmeter-$${JMETER_VERSION} /opt/jmeter
sudo ln -s /opt/jmeter/bin/jmeter /usr/local/bin/jmeter  # add to PATH

echo "JMeter installation completed"
