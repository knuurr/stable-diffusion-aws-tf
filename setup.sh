#!/bin/sh

set -e

# Define color codes
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
reset='\033[0m'  # Reset color to default

CUDA_VERSION="12.2.1"
CUDA_FULL_VERSION="${CUDA_VERSION}_535.86.10"

INSTALL_AUTOMATIC1111="$(curl -s http://169.254.169.254/latest/meta-data/tags/instance/INSTALL_AUTOMATIC1111)"
INSTALL_INVOKEAI="$(curl -s http://169.254.169.254/latest/meta-data/tags/instance/INSTALL_INVOKEAI)"
GUI_TO_START="$(curl -s http://169.254.169.254/latest/meta-data/tags/instance/GUI_TO_START)"

# Use echo with -e flag to enable interpretation of escape sequences
echo -e "${yellow}[*] Configuration:${reset} " \
  "INSTALL_AUTOMATIC1111=${green}$INSTALL_AUTOMATIC1111${reset}, " \
  "INSTALL_INVOKEAI=${green}$INSTALL_INVOKEAI${reset}, " \
  "GUI_TO_START=${green}$GUI_TO_START${reset}"

update_apt () {

  # Inform user about update process
  echo -e "${yellow}[*] Updating package lists...${reset}"
  sudo apt update

  # Commented out upgrade due to potential kernel mismatch
  # echo -e "${yellow}[*] Upgrading packages...${reset}"
  # sudo apt upgrade -y

  # Inform user about installing missing kernel headers
  echo -e "${yellow}[*] Installing missing kernel headers...${reset}"
  sudo apt install -y linux-headers-$(uname -r)

  # Inform user about essential package installation
  echo -e "${yellow}[*] Installing essential packages...${reset}"
  sudo apt install git python3-venv python3-pip python3-dev build-essential net-tools linux-headers-cloud-amd64 pipx -y

  # Inform user about setting up pipx path for user 'admin'
  echo -e "${yellow}[*] Setting up pipx path for user 'admin'...${reset}"
  sudo -u admin pipx ensurepath

  # Inform user about installing useful tools
  echo -e "${yellow}[*] Installing useful tools...${reset}"
  sudo apt install -y tmux htop rsync ncdu

  # Inform user about downloading and installing yq
  echo -e "${yellow}[*] Downloading and installing yq...${reset}"
  sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq && sudo chmod +x /usr/local/bin/yq
}



mount_ephemeral_storage () {

  cat <<EOF | sudo tee /usr/lib/systemd/system/instance-storage.service
[Unit]
Description=Format and mount ephemeral storage
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/usr/sbin/mkfs.ext4 /dev/nvme1n1
ExecStart=/usr/bin/mkdir -p /mnt/ephemeral
ExecStart=/usr/bin/mount /dev/nvme1n1 /mnt/ephemeral
ExecStart=/usr/bin/chmod 777 /mnt/ephemeral
ExecStart=dd if=/dev/zero of=/mnt/ephemeral/swapfile bs=1G count=8
ExecStart=chmod 600 /mnt/ephemeral/swapfile
ExecStart=mkswap /mnt/ephemeral/swapfile
ExecStart=swapon /mnt/ephemeral/swapfile
ExecStop=swapoff /mnt/ephemeral/swapfile
ExecStop=/usr/bin/umount /mnt/ephemeral

[Install]
WantedBy=multi-user.target
EOF
  
  sudo systemctl enable instance-storage
  sudo systemctl start instance-storage

  # Reserve less space for root
  sudo tune2fs -m 1 /dev/nvme0n1p1
}

install_cuda () {

  # Inform user about switching directory
  echo -e "${yellow}[*] Changing directory to /mnt/ephemeral...${reset}"
  cd /mnt/ephemeral

  # Downloading CUDA (masked URL for security)
  echo -e "${yellow}[*] Downloading CUDA ${CUDA_VERSION}...${reset}"
  sudo -u admin wget --no-verbose https://developer.download.nvidia.com/compute/cuda/$CUDA_VERSION/local_installers/cuda_${CUDA_FULL_VERSION}_linux.run

  # Running silent CUDA installer
  echo -e "${yellow}[*] Installing CUDA ${CUDA_VERSION} (silent mode)...${reset}"
  sudo sh cuda_${CUDA_FULL_VERSION}_linux.run --silent

  # Inform user about cleaning up downloaded file
  echo -e "${yellow}[*] Cleaning up temporary CUDA installer...${reset}"
  sudo -u admin rm cuda_${CUDA_FULL_VERSION}_linux.run
}



install_automatic1111 () {
  # Change directory to user 'admin' home
  echo -e "${yellow}[*] Changing directory to /home/admin...${reset}"
  cd /home/admin

  # Install libtcmalloc library
  echo -e "${yellow}[*] Installing libtcmalloc-minimal4...${reset}"
  sudo apt install -y libtcmalloc-minimal4

  # Clone Automatic1111 repository for user 'admin'
  echo -e "${yellow}[*] Cloning Automatic1111 repository...${reset}"
  sudo -u admin git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git


  # Download initial models
  echo -e "${yellow}[*] Creating directory for Stable Diffusion models...${reset}"
  sudo -u admin mkdir -p /home/admin/stable-diffusion-webui/models/Stable-diffusion/
  
  echo -e "${yellow}[*] Downloading pre-trained Stable Diffusion models...${reset}"
  cd /home/admin/stable-diffusion-webui/models/Stable-diffusion/
  sudo -u admin wget --no-verbose https://huggingface.co/stabilityai/stable-diffusion-2-1-base/resolve/main/v2-1_512-ema-pruned.ckpt
  sudo -u admin wget --no-verbose https://huggingface.co/stabilityai/stable-diffusion-2-1/resolve/main/v2-1_768-ema-pruned.ckpt
  
  echo -e "${yellow}[*] Downloading Stable Diffusion configuration files...${reset}"
  sudo -u admin wget --no-verbose https://raw.githubusercontent.com/Stability-AI/stablediffusion/main/configs/stable-diffusion/v2-inference.yaml -O v2-1_512-ema-pruned.yaml
  sudo -u admin wget --no-verbose https://raw.githubusercontent.com/Stability-AI/stablediffusion/main/configs/stable-diffusion/v2-inference-v.yaml -O v2-1_768-ema-pruned.yaml



  cat <<EOF | sudo tee /usr/lib/systemd/system/sdwebgui.service
[Unit]
Description=Stable Diffusion AUTOMATIC1111 Web UI service
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=admin
Environment=TMPDIR=/mnt/ephemeral/tmp
Environment=XDG_CACHE_HOME=/mnt/ephemeral/cache
WorkingDirectory=/home/admin/stable-diffusion-webui/
ExecStart=/usr/bin/env bash /home/admin/stable-diffusion-webui/webui.sh --xformers
StandardOutput=append:/var/log/sdwebui.log
StandardError=append:/var/log/sdwebui.log

[Install]
WantedBy=multi-user.target
EOF


}


install_invokeai () {
  # Set InvokeAI root directory
  export INVOKEAI_ROOT=/home/admin/invokeai
  # echo -e "${yellow}[*] Setting InvokeAI root directory to: ${INVOKEAI_ROOT}${reset}"

  # Add InvokeAI root directory to admin's .bashrc (masked potentially sensitive path)
  echo -e "${yellow}[*] Adding InvokeAI root directory to /home/admin/.bashrc...${reset}"
  echo 'export INVOKEAI_ROOT=/home/admin/invokeai' | tee -a /home/admin/.bashrc

  # Create InvokeAI root directory for user 'admin'
  echo -e "${yellow}[*] Creating InvokeAI root directory for user 'admin'...${reset}"
  sudo -u admin -E mkdir $INVOKEAI_ROOT

  # Handle potential packaging bug with Pipx
  echo -e "${yellow}[*] Addressing potential packaging issue with Pipx...${reset}"
  sudo pip install 'packaging<22' -U --break-system-packages

  # Install InvokeAI with transformers using Pipx for user 'admin'
  echo -e "${yellow}[*] Installing InvokeAI[xformers] using Pipx for user 'admin'...${reset}"
  sudo -u admin -E pipx install "InvokeAI[xformers]" --pip-args "--use-pep517 --extra-index-url https://download.pytorch.org/whl/cu117"

  # Install OpenCV dependencies
  echo -e "${yellow}[*] Installing OpenCV dependencies...${reset}"
  sudo apt install -y python3-opencv libopencv-dev

  # Inject InvokeAI and pypatchmatch for user 'admin' with Pipx
  echo -e "${yellow}[*] Injecting InvokeAI and pypatchmatch for user 'admin' with Pipx...${reset}"
  sudo -u admin -E pipx inject InvokeAI pypatchmatch
  

  cat <<EOF | sudo tee /usr/lib/systemd/system/invokeai.service
[Unit]
Description=Invoke AI GUI
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=admin
Environment=INVOKEAI_ROOT=/home/admin/invokeai
Environment=TMPDIR=/mnt/ephemeral/tmp
Environment=XDG_CACHE_HOME=/mnt/ephemeral/cache
WorkingDirectory=/home/admin/invokeai
ExecStart=/home/admin/.local/bin/invokeai-web
StandardOutput=append:/var/log/invokeai.log
StandardError=append:/var/log/invokeai.log

[Install]
WantedBy=multi-user.target
EOF
  # sudo systemctl enable invokeai
  # Customize a few parameters

  # sudo -u admin -E yq e -i '.InvokeAI.Features.nsfw_checker = false' $INVOKEAI_ROOT/invokeai.yaml
  # Default is 2.75, but that's also assuming an 8GB card
  # sudo -u admin -E yq e -i '.InvokeAI.Memory/Performance.max_vram_cache_size = 8' $INVOKEAI_ROOT/invokeai.yaml
}


enable_webgui () {

  # Check if Automatic1111 web UI is requested
  if [ "$GUI_TO_START" = "automatic1111" ]; then
    echo -e "${yellow}[*] Enabling and starting Automatic1111 web service (sdwebgui)...${reset}"
    sudo systemctl enable sdwebgui
    sudo systemctl start sdwebgui
  fi

  # Check if InvokeAI web UI is requested
  if [ "$GUI_TO_START" = "invokeai" ]; then
    echo -e "${yellow}[*] Enabling and starting InvokeAI web service...${reset}"
    sudo systemctl enable invokeai
    sudo systemctl start invokeai
  fi

  # No matching GUI found (optional)
  if [ "$GUI_TO_START" != "automatic1111" ] && [ "$GUI_TO_START" != "invokeai" ]; then
    echo -e "${yellow}[*] No matching web UI found for: ${GUI_TO_START}${reset}"
  fi
}




### MAIN LOGIC ###

update_apt
mount_ephemeral_storage
install_cuda

export TMPDIR=/mnt/ephemeral/tmp
export XDG_CACHE_HOME=/mnt/ephemeral/cache
echo 'export TMPDIR=/mnt/ephemeral/tmp' | tee -a /home/admin/.bashrc
echo 'export XDG_CACHE_HOME=/mnt/ephemeral/cache' | tee -a /home/admin/.bashrc

sudo mkdir $TMPDIR
sudo mkdir $XDG_CACHE_HOME
sudo chmod 777 $TMPDIR $XDG_CACHE_HOME

if [ "$INSTALL_AUTOMATIC1111" = "true" ]; then
  install_automatic1111
# sudo systemctl enable sdwebgui
fi

if [ "$INSTALL_INVOKEAI" = "true" ]; then

  install_invokeai

fi

enable_webgui
