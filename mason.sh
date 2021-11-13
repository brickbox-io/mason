#!/bin/bash

# First script to run on a new host to setup the connection to the server.

# --------------------------------- Processes -------------------------------- #
# 1. Create "bb_root" user
# 2. Create "/etc/sshtunnel" directory
# 3. Generate sshtunnel key pair
# 4. Read the host serial number
# 5. POST the host serial number and sshtunnel public key to the server using the API key
# 6. Retrive the bb_root public key and add to authorized_keys
# 7. Recive back assigned SSH tunnel port
# 8. Create the SSH tunnel

# Arguments:
# api_key=$1

# Flags
DEBUG=0 # -d

# ---------------------------------------------------------------------------- #
#                               GPU Fingerprints                               #
# ---------------------------------------------------------------------------- #

# A lsit of the supported GPUs and their PCI IDs

declare -A supported_gpus_vga

# supported_gpus_vga["Nvidia GeForce RTX 3070 - VGA"]="10de:2484"
# supported_gpus_vga["Nvidia GeForce RTX 3090 - VGA"]="10de:2204"
supported_gpus_vga["3070"]="10de:2484"
supported_gpus_vga["3090"]="10de:2204"

declare -A supported_gpus_audio
# supported_gpus_audio["Nvidia GeForce RTX 3070 - Audio"]="10de:228b"
# supported_gpus_audio["Nvidia GeForce RTX 3090 - Audio"]="10de:1aef"
supported_gpus_audio["3070_audio"]="10de:228b"
supported_gpus_audio["3090_audio"]="10de:1aef"

# ---------------------------------------------------------------------------- #
#                                 Configuration                                #
# ---------------------------------------------------------------------------- #

while getopts ":d" flags; do
  case "${flags}" in
    d) DEBUG=1 ;;
    \?) echo "Invalid option: -${OPTARG}" >&2;
    exit 1 ;;
  esac
done

if [ $DEBUG -eq 1 ]; then
    url='dev.brickbox.io'
    ip='134.209.214.111'
elif [ $DEBUG -eq 0 ]; then
    url='brickbox.io'
    ip='143.244.165.205'
fi

onboarding_endpoint='vm/host/onboarding'
onboarding_pubkey_endpoint='vm/host/onboarding/pubkey'
onboarding_sshport_endpoint='vm/host/onboarding/sshport'
onboarding_gpu_endpoint='vm/host/onboarding/gpu'


# ---------------------------------- bb_root --------------------------------- #
if [[ ! $(id -u bb_root > /dev/null 2>&1) ]]; then
    useradd -m -s /bin/bash bb_root
    usermod -aG sudo bb_root
    mkdir -p ~bb_root/.ssh/ && touch ~bb_root/.ssh/authorized_keys
    echo "bb_root    ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers > /dev/null
else
    mkdir -p ~bb_root/.ssh/ && touch ~bb_root/.ssh/authorized_keys
fi


# -------------------------------- SSH Tunnel -------------------------------- #
mkdir -p /etc/sshtunnel
if [ ! -f /etc/sshtunnel/id_rsa ]; then
    ssh-keygen -qN "" -f /etc/sshtunnel/id_rsa
fi
pub_key=$(cat /etc/sshtunnel/id_rsa.pub)


# ----------------------------- SSH Configuration ---------------------------- #
sudo sed -i '/PermitRootLogin prohibit-password/s/^#//g' /etc/ssh/sshd_config
sudo sed -i '/AuthorizedKeysFile/s/^#//g' /etc/ssh/sshd_config
sudo sed -i '/PubkeyAuthentication/s/^#//g' /etc/ssh/sshd_config

if  ! grep -q "bb_root" /etc/ssh/sshd_config; then
    sudo sed -i '/AuthorizedKeysFile/ s|$| /home/bb_root/.ssh/authorized_keys|' /etc/ssh/sshd_config
    echo "AllowUsers root bb_root brickbox" | sudo tee -a /etc/ssh/sshd_config > /dev/null
fi

sudo chmod 755 /home/bb_root/.ssh
sudo chmod 644 /home/bb_root/.ssh/authorized_keys


# ------------------------------- Serial Number ------------------------------ #
host_serial=$(dmidecode -s system-serial-number)

onboarding_init=$(curl -H "Content-Type: application/x-www-form-urlencoded; charset=utf-8" \
                    --data-urlencode "public_key=$pub_key" \
                    -X POST "https://$url/$onboarding_endpoint/$host_serial/" )


# ---------------------------------------------------------------------------- #
#                              System Modification                             #
# ---------------------------------------------------------------------------- #
if [[ "$onboarding_init" == "ok" ]]; then

    # ------------------------------ bb_root PubKey ------------------------------ #
    bb_root_pubkey=$(curl -H "Content-Type: application/x-www-form-urlencoded; charset=utf-8" \
                    -d "host_serial=$host_serial" \
                    -X POST "https://$url/$onboarding_pubkey_endpoint/$host_serial/")

    if [[ "$bb_root_pubkey" != "error" ]]; then
        echo "$bb_root_pubkey" > temp_authorized_keys

        if ssh-keygen -l -f temp_authorized_keys; then
            echo "$bb_root_pubkey" >> ~bb_root/.ssh/authorized_keys
            rm temp_authorized_keys
        else
            echo "Error: $bb_root_pubkey is not a valid public key."
            rm temp_authorized_keys
            exit 1
        fi

    else
        echo "Failed to retrieve bb_root public key"
        exit 1
    fi


    # ----------------------- GPU Passthrough Configuration ---------------------- #

    # Find GPU
    gpu_name=false

    echo "${!supported_gpus_vga[@]}"

    for gpu in "${!supported_gpus_vga[@]}"; do
        echo "$gpu"
        echo "${supported_gpus_vga[$gpu]}"
        gpu_count="$(lspci -vnn | grep -c "${supported_gpus_vga[$gpu}]}")"
        echo "GPU Count: $gpu_count"
        if [[ "$gpu_count" -gt 0 ]]; then
            gpu_name=$gpu
            gpu_pci_id=${supported_gpus_vga[$gpu]}

            for audio in "${!supported_gpus_audio[@]}"; do
                gpu_audio_count=$(lspci -vnn | grep -c "${supported_gpus_audio[$audio]}")
                if [[ "$gpu_audio_count" -gt 0 ]]; then
                    # gpu_audio_name=$audio
                    gpu_audio_pci_id=${supported_gpus_audio[$audio]}
                    break
                fi
            done

            break
        fi
    done

    if [[ "$gpu_name" == "false" ]]; then
        echo "No supported GPU found."
        exit 1
    fi

    #Register GPUs
    lspci -vnn | grep -c "$gpu_pci_id" | while read -r gpu_result ; do
        echo "location: ${gpu_result:0:2}"
    done

    # IOMMU
    cpu_vendor=$(sudo cat /proc/cpuinfo | grep 'vendor' | uniq | cut -d':' -f2 | xargs)
    if [[ $cpu_vendor == "GenuineIntel" ]]; then
        REPLACEMENT_VALUE="intel_iommu=on"
    elif [[ $cpu_vendor == "AuthenticAMD" ]]; then
        REPLACEMENT_VALUE="amd_iommu=on iommu=pt"
    fi

    sudo sed -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT *= *\).*/\1$REPLACEMENT_VALUE/" /etc/default/grub
    sudo update-grub

    # validate_iommu=$(dmesg | grep iommu) # Check if iommu is enabled. (Might not be working)

    # initramfs-tools
    if ! grep -q "vfio" /etc/initramfs-tools/modules; then
        echo "softdep amdgpu pre: vfio vfio_pci" | sudo tee -a /etc/initramfs-tools/modules > /dev/null
        echo "vfio" | sudo tee -a /etc/initramfs-tools/modules > /dev/null
        echo "vfio_iommu_type1" | sudo tee -a /etc/initramfs-tools/modules > /dev/null
        echo "vfio_virqfd" | sudo tee -a /etc/initramfs-tools/modules > /dev/null
        echo "options vfio_pci ids=$gpu_pci_id,$gpu_audio_pci_id" | sudo tee -a /etc/initramfs-tools/modules > /dev/null
        echo "vfio_pci ids=$gpu_pci_id,$gpu_audio_pci_id" | sudo tee -a /etc/initramfs-tools/modules > /dev/null
        echo "vfio_pci" | sudo tee -a /etc/initramfs-tools/modules > /dev/null
        echo "nvidia" | sudo tee -a /etc/initramfs-tools/modules > /dev/null
    fi

    # Modules
    if  ! grep -q "vfio" /etc/modules; then
        echo "vfio" | sudo tee -a /etc/modules > /dev/null
        echo "vfio_iommu_type1" | sudo tee -a /etc/modules > /dev/null
        echo "vfio_pci ids=$gpu_pci_id,$gpu_audio_pci_id" | sudo tee -a /etc/modules > /dev/null
    fi

    # Nvidia Config
    touch /etc/modprobe.d/nvidia.conf
    if [ ! -f /etc/modprobe.d/nvidia.conf ]; then
        echo "softdep nvidia pre: vfio vfio_pci" | sudo tee -a /etc/modprobe.d/nvidia.conf > /dev/null
    fi

    # Modprobe VFIO
    touch /etc/modprobe.d/vfio_pci.conf
    if ! grep -q "options vfio_pci ids" /etc/modprobe.d/vfio_pci.conf ; then
        echo "options vfio_pci ids=$gpu_pci_id,$gpu_audio_pci_id" | sudo tee -a /etc/modprobe.d/vfio_pci.conf> /dev/null
    fi

    touch /etc/modprobe.d/vfio.conf
    if ! grep -q "options vfio_pci ids" /etc/modprobe.d/vfio.conf ; then
        echo "options vfio_pci ids=$gpu_pci_id,$gpu_audio_pci_id" | sudo tee -a /etc/modprobe.d/vfio.conf > /dev/null
    fi

    # Blacklist nouveau
    if ! grep -q "nouveau" /etc/modprobe.d/blacklist.conf; then
        echo "blacklist nouveau" | sudo tee -a /etc/modprobe.d/blacklist.conf > /dev/null
    fi

    # Commit Changes
    sudo update-initramfs -u -k all

    # ------------------------------- Assigned Port ------------------------------ #
    assigned_port=$(curl -H "Content-Type: application/x-www-form-urlencoded; charset=utf-8" \
                    -X POST "https://$url/$onboarding_sshport_endpoint/$host_serial/")
    if [[ $assigned_port != "error" ]]; then
        echo "Assigned SSH tunnel port: $assigned_port"
    else
        echo "Failed to retrieve assigned SSH tunnel port"
        exit 1
    fi

else
    echo "Failed to onboard host."
    exit 1
fi

cat <<EOF > /etc/systemd/system/sshtunnel.service
[Unit]
Description=Service to maintain an ssh reverse tunnel
Wants=network-online.target
After=network-online.target
StartLimitIntervalSec=0
[Service]
Type=simple
ExecStart=/usr/bin/ssh -qNn \\
  -o ServerAliveInterval=30 \\
  -o ServerAliveCountMax=3 \\
  -o ExitOnForwardFailure=yes \\
  -o StrictHostKeyChecking=no \\
  -o UserKnownHostsFile=/dev/null \\
  -i /etc/sshtunnel/id_rsa \\
  -R :$assigned_port:localhost:22 \\
  sshtunnel@$ip -p 22
Restart=always
RestartSec=60
[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now sshtunnel
systemctl daemon-reload
