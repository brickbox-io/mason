# Mason - brickbox.io

[![Script Check](https://github.com/brickbox-io/mason/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/brickbox-io/mason/actions/workflows/shellcheck.yml)

**Repository is intended for hosts, NOT end users. All hosts are manually vetted and approved by brickbox.io at this time.**

## Installation

The following command will download and run the mason.py file.

```bash
sudo wget -qO- mason.brickbox.io | bash /dev/stdin [arguments] [options]
```

**ONLY FOR 3090s CURRENTLY**

| Option Flag | Description |
|-------------|-------------|
| -d          | Debug Flag  |

## Operations

| Process                      | Description                                                                                                              |
|------------------------------|--------------------------------------------------------------------------------------------------------------------------|
| bb_root                      | Check if the user "bb_root" exsists, if not create it and set to root. Create SSH storage location if it does not exist. |
| SSH Tunnel                   | Create sshtunnel directory (/etx/sshtunnel/ and create SSH key.                                                          |
| Serial Number                | Read the host serial number and confirm it is registered with brickbox.io "OK" status indicates readiness.               |
| bb_root PubKey               | Receive the pubkey for bb_root from brickbox.io then validate it before adding to authorized key file.                   |
| Find GPU                     | Cycles through the compatible GPUs and finds a match, otherwise exits.                                                   |
| GPU Pass - IOMMMU            | Configure the system for IOMMU based on the install CPU manufacturer.                                                    |
| GPU Pass - initramfs-tools   | Configure boot time behavior.                                                                                            |
| GPU Pass - Modules           | Add new driver module.                                                                                                   |
| GPU Pass - Modprobe Nidia    | Add the NVidia driver to modprobe.                                                                                       |
| GPU Pass - Modprobe VFIO     | Add the VFIO driver to modprobe.                                                                                         |
| GPU Pass - Blacklist nouveau | Add the nouveau driver to modprobe blacklist.                                                                            |
| Assigned Prot                | Receive the assigned port from brickbox.io to be used for the SSH tunnel.                                                |


https://mathiashueber.com/windows-virtual-machine-gpu-passthrough-ubuntu/

https://askubuntu.com/questions/1166317/module-nvidia-is-in-use-but-there-are-no-processes-running-on-the-gpu

https://linuxconfig.org/how-to-disable-blacklist-nouveau-nvidia-driver-on-ubuntu-20-04-focal-fossa-linux
