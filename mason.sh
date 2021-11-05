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
api_key=$1

# Flags
DEBUG=0

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


# Check if the user "bb_root" exsists, if not create it and set to root.
if ! id -u bb_root > /dev/null 2>&1; then
    useradd -m -s /bin/bash bb_root
    usermod -aG sudo bb_root
fi

mkdir -p ~bb_root/.ssh/ && touch ~bb_root/.ssh/authorized_keys

# Create "/etc/sshtunnel" directory
mkdir -p /etc/sshtunnel

# Generate sshtunnel key pair if it does not exist
if [ ! -f /etc/sshtunnel/id_rsa ]; then
    ssh-keygen -qN "" -f /etc/sshtunnel/id_rsa
fi
pub_key=$(cat /etc/sshtunnel/id_rsa.pub)

# Read the host serial number
host_serial=$(dmidecode -s system-serial-number)

# Confirm the host serial number and access before proceeding.
onboarding_init=$(curl -H "Content-Type: application/x-www-form-urlencoded; charset=utf-8" \
                    --data-urlencode "public_key=$pub_key" \
                    -X POST "https://$url/$onboarding_endpoint/$host_serial/" )
http_code=$(tail -n1 <<< "$onboarding_init")

echo "Onboarding init: $onboarding_init"


if [[ $onboarding_init == "ok" ]]; then

    bb_root_pubkey=$(curl -H "Content-Type: application/x-www-form-urlencoded; charset=utf-8" \
                    -d "host_serial=$host_serial" \
                    -X POST "https://$url/$onboarding_pubkey_endpoint/$host_serial/")

    if [[ $bb_root_pubkey != "error" ]]; then
        echo "bb_root public key: $bb_root_pubkey"
        echo "$bb_root_pubkey" > temp_authorized_keys

        if ssh-keygen -l -f temp_authorized_keys; then
            echo $bb_root_pubkey >> ~bb_root/.ssh/authorized_keys
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

    assigned_port=$(curl -H "Content-Type: application/x-www-form-urlencoded; charset=utf-8" \
                    -X POST "https://$url/$onboarding_sshport_endpoint/$host_serial/")
    if [[ $assigned_port != "error" ]]; then
        echo "Assigned SSH tunnel port: $assigned_port"
    else
        echo "Failed to retrieve assigned SSH tunnel port"
        exit 1
    fi


    # ----------------------- GPU Passthrough Configuration ---------------------- #

    # Chcke if CPU is AMD or Intel and then configure grub for iommu.
    cpu_vendor=$(/proc/cpuinfo | grep 'vendor' | uniq)
    if [ $cpu_vendor == "GenuineIntel"]; then
        REPLACEMENT_VALUE="intel_iommu=on"

    elif [ $cpu_vendor == "AuthenticAMD"]; then
        REPLACEMENT_VALUE="amd_iommu=on iommu=pt"
    fi

    sed -c -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT *= *\).*/\1$REPLACEMENT_VALUE/" /etc/default/grub
    sudo update-grub

    validate_iommu=$(dmesg | grep iommu) # Check if iommu is enabled.



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



/etc/initramfs-tools/modules

softdep amdgpu pre: vfio vfio_pci

vfio
vfio_iommu_type1
vfio_virqfd
options vfio_pci ids=10de:2204,10de:1aef
vfio_pci ids=10de:2204,10de:1aef
vfio_pci
nvidia


/etc/modules/

vfio
vfio_iommu_type1
vfio_pci ids=10de:2204,10de:1aef



/etc/modprobe.d/nvidia.conf

softdep nvidia pre: vfio vfio_pci



/etc/modprobe.d/vfio_pci.conf

options vfio_pci ids=10de:2204,10de:1aef


https://mathiashueber.com/windows-virtual-machine-gpu-passthrough-ubuntu/
sudo update-initramfs -u -k all

10de:2484, 10de:228b


add to the bottom of blacklist.conf

blacklist nouveau


https://askubuntu.com/questions/1166317/module-nvidia-is-in-use-but-there-are-no-processes-running-on-the-gpu
https://linuxconfig.org/how-to-disable-blacklist-nouveau-nvidia-driver-on-ubuntu-20-04-focal-fossa-linux
