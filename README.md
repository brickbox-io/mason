<div align="center">

<h1>Mason by brickbox.io</h1>

[![Script Check](https://github.com/brickbox-io/mason/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/brickbox-io/mason/actions/workflows/shellcheck.yml)

</div>

## Table of Contents

- [Table of Contents](#table-of-contents)
- [What is Mason?](#what-is-mason)
- [Getting Started](#getting-started)
- [Operations](#operations)
- [Directory Structure](#directory-structure)

## What is Mason?

**Repository is intended for hosts, NOT end users. All hosts are manually vetted and approved by brickbox.io at this time.**

Mason is an onboarding script to streamline the processes of connecting pre-qualified hosts to the [brickbox.io](brickbox.io) platform. The repository also contains additional onboarding scripts that are used as part of our virtualization platform.

## Getting Started

For quick installation the mason.sh script has been mapped to [mason.brickbox.io](mason.brickbox.io) and can be downloaded and ran with the following line:

```bash
sudo wget -qO- mason.brickbox.io | bash /dev/stdin [options] [arguments]
```

| Option Flag | Description | Example                             |
|:-----------:|-------------|-------------------------------------|
|     -d      | Debug Flag  | sudo wget -qO- mason.brickbox.io \| bash /dev/stdin-d |

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

## Directory Structure

```default
.
├── .github     # CI/CD using GitHub Actions and other functions.
├── mason.sh    # Primary onboarding script.
└── LICENSE     # Repository license.
```
