# V7 DevOps Technical Assessment

A containerized three-VM DevOps environment built with Docker, Ubuntu, SSH, iptables, Ansible, Nginx, TLS, reverse proxying, load balancing, and automated verification.

## Overview

This project implements a three-node environment that simulates virtual machines using Ubuntu Docker containers.

The environment demonstrates:

- Dockerized Ubuntu VMs
- Custom Docker networking
- Container-level firewall configuration using iptables
- SSH key-based authentication
- Disabled SSH password authentication
- Disabled direct root SSH login
- Local DNS-style hostname resolution
- Self-signed HTTPS on VM1
- Nginx web servers on all VMs
- Ansible automation and idempotency
- Ansible Vault for encrypted secrets
- Nginx reverse proxying
- Nginx load balancing
- Automatic failover when VM2 becomes unavailable
- Automatic rejoining of VM2 after recovery
- Automated verification using `verify.sh`

---

# Architecture

```text
                         WSL / Host
                            |
                            |
                    Docker Network
                      v7-network
                    172.30.0.0/24
                            |
          +-----------------+-----------------+
          |                 |                 |
          |                 |                 |
     +----v----+       +----v----+       +----v----+
     |   VM1   |       |   VM2   |       |   VM3   |
     | .11     |       | .12     |       | .13     |
     +----+----+       +----+----+       +----+----+
          |                 ^                 ^
          |                 |                 |
          |            HTTP from VM1    HTTP from VM1
          |
     Nginx HTTPS
     Reverse Proxy
     Load Balancer
          |
       /app/
       /vm2/
       /vm3/
