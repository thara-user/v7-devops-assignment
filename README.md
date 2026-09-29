# V7 DevOps Technical Assessment

## Docker-Based Virtual Infrastructure with Ansible Automation and a Hardened Nginx Reverse Proxy

This project implements a small, secure, automated virtual infrastructure using Docker, Ubuntu, Nginx, Ansible, SSH key authentication, iptables, TLS, reverse proxying, load balancing, and backend failover.

The environment simulates three Ubuntu servers:

* **VM1** – Nginx HTTPS frontend, reverse proxy, and load balancer
* **VM2** – Backend web server
* **VM3** – Backend web server

The project demonstrates secure server access, infrastructure automation, HTTP/HTTPS configuration, reverse proxying, load balancing, failure handling, and recovery.

---

## 1. Project Objectives

The main objectives of this assessment are:

* Create three isolated Ubuntu-based environments using Docker.
* Configure a custom Docker network with static IP addresses.
* Configure firewall rules using iptables.
* Secure SSH using public-key authentication.
* Disable SSH password authentication.
* Disable direct root SSH login.
* Configure local domain names.
* Configure HTTPS using a self-signed TLS certificate.
* Automate server configuration using Ansible.
* Use Ansible roles for reusable configuration.
* Protect secrets using Ansible Vault.
* Demonstrate Ansible idempotency.
* Configure Nginx on all three servers.
* Configure VM1 as a reverse proxy.
* Configure load balancing between VM2 and VM3.
* Demonstrate backend failure and automatic failover.
* Demonstrate backend recovery and rejoining.
* Provide automated verification of the infrastructure.

---

# 2. Architecture

```text
                         Client / Browser
                                |
                                | HTTPS
                                |
                    public.vm1.local
                                |
                                v
                    +----------------------+
                    |        VM1           |
                    |      Ubuntu          |
                    |                      |
                    |      Nginx           |
                    |      HTTPS/TLS        |
                    |      Reverse Proxy   |
                    |      Load Balancer   |
                    |      Firewall        |
                    |      SSH             |
                    +----------+-----------+
                               |
                    +----------+----------+
                    |                     |
                 /vm2/                 /vm3/
                    |                     |
                    v                     v
             +-------------+       +-------------+
             |    VM2      |       |    VM3      |
             |   Ubuntu    |       |   Ubuntu    |
             |   Nginx     |       |   Nginx     |
             |   Backend   |       |   Backend   |
             |   Firewall  |       |   Firewall  |
             |   SSH       |       |   SSH       |
             +-------------+       +-------------+

                     /app/
                       |
                  Load Balancing
                  between VM2/VM3
```

### Failure scenario

When VM2 becomes unavailable:

```text
                         VM1
                          |
                    Nginx /app
                          |
                    VM2 - FAILED
                          X
                          |
                          v
                    VM3 - ACTIVE
```

After VM2 is restarted:

```text
                         VM1
                       Nginx
                      /     \
                     v       v
                   VM2     VM3
                   UP       UP
```

---

# 3. Technology Stack

| Technology     | Purpose                              |
| -------------- | ------------------------------------ |
| Ubuntu 24.04   | Operating system inside containers   |
| Docker         | Containerized VM-like environments   |
| Docker Network | Private communication between VMs    |
| iptables       | Inbound firewall rules               |
| OpenSSH        | Secure server administration         |
| Nginx          | Web server and reverse proxy         |
| TLS/SSL        | HTTPS encryption                     |
| Ansible        | Infrastructure automation            |
| Ansible Vault  | Secret protection                    |
| Git/GitHub     | Version control and project delivery |
| Bash           | Automation and verification scripts  |

---

# 4. Project Structure

```text
v7-devops-assignment/
│
├── docker/
│   ├── vm1/
│   │   ├── Dockerfile
│   │   └── start.sh
│   │
│   ├── vm2/
│   │   ├── Dockerfile
│   │   └── start.sh
│   │
│   └── vm3/
│       ├── Dockerfile
│       └── start.sh
│
├── ansible/
│   ├── inventory.ini
│   ├── ansible.cfg
│   ├── site.yml
│   │
│   ├── group_vars/
│   │   └── all/
│   │       └── vault.yml
│   │
│   └── roles/
│       ├── common/
│       ├── ssh/
│       └── nginx/
│
├── verify.sh
├── README.md
└── .gitignore
```

Sensitive files such as private SSH keys, backup files, and Vault passwords are excluded from Git using `.gitignore`.

---

# 5. Docker Infrastructure

Three Ubuntu-based Docker containers are used:

| Container |  IP Address |  SSH |     HTTP | HTTPS |
| --------- | ----------: | ---: | -------: | ----: |
| vm1       | 172.30.0.11 | 2221 |     8081 |  8443 |
| vm2       | 172.30.0.12 | 2222 | Internal |     - |
| vm3       | 172.30.0.13 | 2223 | Internal |     - |

The Docker network is:

```text
Network: v7-network
Subnet: 172.30.0.0/24
```

The containers use:

```text
--restart unless-stopped
```

so Docker automatically restarts them after an unexpected container restart.

---

# 6. Docker Network

The containers communicate through the custom Docker network:

```text
172.30.0.0/24
```

Static addresses:

```text
172.30.0.11  → vm1
172.30.0.12  → vm2
172.30.0.13  → vm3
```

VM1 communicates with the backend servers using their Docker DNS names:

```text
vm2
vm3
```

This avoids hard-coding backend IP addresses in the Nginx upstream configuration.

---

# 7. Firewall Configuration

Each container has an iptables INPUT firewall configured with:

```text
Default INPUT policy: DROP
```

The firewall allows only the required traffic.

## VM1

Allowed:

```text
SSH      → TCP 22
HTTP     → TCP 80
HTTPS    → TCP 443
ICMP     → Echo request
Established/related connections
Loopback
```

## VM2 and VM3

Allowed:

```text
SSH      → TCP 22
HTTP     → TCP 80 from VM1
ICMP     → Echo request
Established/related connections
Loopback
```

VM2 and VM3 do not expose their HTTP services to arbitrary external sources.

> Note: Because this assessment uses Docker containers to simulate VMs, the firewall is implemented as container-level iptables rules with the required network capability.

Firewall verification:

```bash
docker exec vm1 iptables -L INPUT -n --line-numbers
docker exec vm2 iptables -L INPUT -n --line-numbers
docker exec vm3 iptables -L INPUT -n --line-numbers
```

---

# 8. SSH Security

OpenSSH is installed and configured on all three containers.

SSH authentication uses an Ed25519 public/private key pair.

The SSH configuration enforces:

```text
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
```

Therefore:

```text
SSH private key authentication → Allowed
Password authentication        → Rejected
Direct root SSH login          → Disabled
```

Example key-based connection:

```bash
ssh -i ~/.ssh/v7_devops_key -p 2221 devops@127.0.0.1
```

Password authentication verification:

```bash
ssh -o PreferredAuthentications=password \
    -o PubkeyAuthentication=no \
    -o BatchMode=yes \
    -p 2221 devops@127.0.0.1 true
```

The expected result is:

```text
Permission denied (publickey).
```

Private SSH keys are never committed to the repository.

---

# 9. Local Domain Configuration

The following local hostnames are configured:

```text
public.vm1.local
public.vm2.local
public.vm3.local
```

The local `/etc/hosts` file maps them to the Docker IP addresses:

```text
172.30.0.11 public.vm1.local
172.30.0.12 public.vm2.local
172.30.0.13 public.vm3.local
```

This allows the infrastructure to be tested using hostnames instead of directly using IP addresses.

---

# 10. TLS / HTTPS

VM1 provides HTTPS for:

```text
https://public.vm1.local
```

A self-signed TLS certificate is used for this local assessment environment.

Certificate:

```text
/etc/nginx/ssl/public.vm1.local.crt
```

Private key:

```text
/etc/nginx/ssl/public.vm1.local.key
```

The private key is not committed to GitHub.

Because the certificate is self-signed, browsers may display a certificate trust warning such as:

```text
NET::ERR_CERT_AUTHORITY_INVALID
```

This is expected for a locally generated self-signed certificate.

HTTP requests are redirected to HTTPS:

```text
http://public.vm1.local
        |
        v
301 Moved Permanently
        |
        v
https://public.vm1.local
```

Verification:

```bash
curl -I http://public.vm1.local
```

Expected result:

```text
HTTP/1.1 301 Moved Permanently
Location: https://public.vm1.local/
```

HTTPS verification:

```bash
curl -k https://public.vm1.local
```

---

# 11. Nginx Configuration

Nginx is installed on all three servers.

VM1 provides:

* HTTPS
* HTTP to HTTPS redirect
* Reverse proxy
* Load balancing

VM2 and VM3 provide backend HTTP services.

Each backend page displays its hostname and current system time.

Example:

```text
V7 DevOps Assignment

Hostname: vm2
Server time: ...
Nginx is working successfully.
```

---

# 12. VM1 Reverse Proxy

VM1 acts as the entry point for the backend services.

## VM2 Proxy

```text
https://public.vm1.local/vm2/
```

is forwarded to:

```text
vm2:80
```

Verification:

```bash
curl -k https://public.vm1.local/vm2/
```

## VM3 Proxy

```text
https://public.vm1.local/vm3/
```

is forwarded to:

```text
vm3:80
```

Verification:

```bash
curl -k https://public.vm1.local/vm3/
```

---

# 13. Load Balancing

The `/app/` path uses an Nginx upstream group:

```nginx
upstream app_backend {
    server vm2:80 max_fails=2 fail_timeout=5s;
    server vm3:80 max_fails=2 fail_timeout=5s;
}
```

Requests to:

```text
https://public.vm1.local/app/
```

are distributed between VM2 and VM3.

Test:

```bash
for i in {1..10}; do
    curl -sk https://public.vm1.local/app/
    echo
done
```

The responses demonstrate that both backend servers can serve the application.

Example:

```text
Hostname: vm2
Hostname: vm3
Hostname: vm2
Hostname: vm3
...
```

---

# 14. Backend Failure and Failover

The failover test demonstrates that the application continues to respond when one backend server becomes unavailable.

First, VM2 is stopped:

```bash
docker stop vm2
```

Then `/app/` is continuously tested:

```bash
for i in {1..10}; do
    curl -sk https://public.vm1.local/app/
    echo
done
```

VM2 is unavailable, but VM3 continues serving requests.

Expected behavior:

```text
VM2 → FAILED
VM3 → SERVING REQUESTS
```

No manual Nginx reload is required.

Nginx uses passive failure detection through:

```text
max_fails
fail_timeout
proxy_next_upstream
```

to fail over to an available backend.

---

# 15. VM2 Recovery and Rejoining

VM2 is restarted:

```bash
docker start vm2
```

Wait for the service to become available:

```bash
sleep 5
```

Then test `/app/` again:

```bash
for i in {1..10}; do
    curl -sk https://public.vm1.local/app/
    echo
done
```

The backend responses again include VM2 and VM3.

This demonstrates that VM2 can recover and rejoin the backend pool without manually reloading the Nginx configuration.

---

# 16. Ansible Automation

Ansible is used to automate configuration of all three servers.

Inventory:

```text
vm1 → 172.30.0.11
vm2 → 172.30.0.12
vm3 → 172.30.0.13
```

The inventory uses:

```text
ansible_user=devops
```

and the configured SSH private key.

The project contains:

```text
ansible.cfg
inventory.ini
site.yml
roles/
```

---

# 17. Ansible Roles

The project uses three roles.

## common

The common role:

* Installs required packages.
* Installs curl.
* Installs Git.
* Installs sudo.
* Installs Docker.
* Creates `ansible_user`.
* Adds `ansible_user` to the sudo group.
* Configures passwordless sudo through `/etc/sudoers.d/`.
* Verifies that the Vault secret is available.

## ssh

The SSH role:

* Installs/configures SSH key authentication.
* Disables password authentication.
* Disables direct root login.
* Enables public-key authentication.
* Validates the SSH configuration.

## nginx

The Nginx role:

* Installs Nginx.
* Configures the backend Nginx servers.
* Configures the VM1 reverse proxy.
* Configures HTTPS.
* Configures the `/vm2/` and `/vm3/` proxy paths.
* Configures the `/app/` upstream.

---

# 18. Ansible Vault

Sensitive configuration is protected using Ansible Vault.

The encrypted Vault file is:

```text
ansible/group_vars/all/vault.yml
```

The repository does not contain the Vault password.

The encrypted file begins with:

```text
$ANSIBLE_VAULT;1.1;AES256
```

Ansible commands requiring the Vault data are executed with:

```bash
--ask-vault-pass
```

Example:

```bash
ansible all -m ping --ask-vault-pass
```

No secret values or Vault passwords are documented in this README.

---

# 19. Ansible Connectivity Verification

Run:

```bash
cd ~/v7-devops-assignment/ansible
ansible all -m ping --ask-vault-pass
```

Expected result:

```text
vm1 SUCCESS
vm2 SUCCESS
vm3 SUCCESS
```

This confirms that Ansible can connect to all managed servers.

---

# 20. Ansible Idempotency

The configuration is designed to be idempotent.

The first execution makes the required changes:

```bash
ansible-playbook site.yml --ask-vault-pass
```

The second execution should not make unnecessary changes:

```bash
ansible-playbook site.yml --ask-vault-pass
```

The second execution produced:

```text
changed=0
```

This demonstrates that the desired configuration is already present and the playbook can safely be executed again.

---

# 21. Automated Verification

The repository includes:

```text
verify.sh
```

The script verifies important parts of the environment, including:

* Docker containers
* Restart policies
* Firewall policy
* SSH service
* Nginx service
* Nginx configuration
* HTTPS
* HTTP to HTTPS redirect
* VM2 reverse proxy
* VM3 reverse proxy
* Load balancing
* Ansible connectivity

Run:

```bash
cd ~/v7-devops-assignment
./verify.sh
```

The completed verification produced:

```text
PASSED: 24
FAILED: 0

ALL AUTOMATED CHECKS PASSED
```

---

# 22. Useful Verification Commands

### Check containers

```bash
docker ps
```

### Check network

```bash
docker network inspect v7-network
```

### Check restart policy

```bash
docker inspect -f '{{.Name}} -> {{.HostConfig.RestartPolicy.Name}}' vm1 vm2 vm3
```

### Check firewall

```bash
docker exec vm1 iptables -L INPUT -n --line-numbers
docker exec vm2 iptables -L INPUT -n --line-numbers
docker exec vm3 iptables -L INPUT -n --line-numbers
```

### Test HTTPS

```bash
curl -k https://public.vm1.local
```

### Test HTTP redirect

```bash
curl -I http://public.vm1.local
```

### Test VM2 reverse proxy

```bash
curl -k https://public.vm1.local/vm2/
```

### Test VM3 reverse proxy

```bash
curl -k https://public.vm1.local/vm3/
```

### Test load balancing

```bash
for i in {1..10}; do
    curl -sk https://public.vm1.local/app/
    echo
done
```

### Test failover

```bash
docker stop vm2

for i in {1..10}; do
    curl -sk https://public.vm1.local/app/
    echo
done
```

### Test recovery

```bash
docker start vm2

sleep 5

for i in {1..10}; do
    curl -sk https://public.vm1.local/app/
    echo
done
```

---

# 23. Security Considerations

The project implements the following security measures:

* Default-deny inbound firewall policy.
* SSH key-based authentication.
* SSH password authentication disabled.
* Direct root SSH login disabled.
* Backend HTTP access restricted to VM1.
* TLS enabled on VM1.
* Secrets protected with Ansible Vault.
* Private SSH keys excluded from Git.
* TLS private keys excluded from Git.
* Backup files excluded from Git.
* Environment and credential files excluded using `.gitignore`.

No private credentials or secret passwords are included in the public repository.

---

# 24. Evidence / Demonstration

The demonstration video covers:

1. Docker containers.
2. Docker network.
3. Restart policies.
4. Firewall configuration.
5. SSH key authentication.
6. Rejected password authentication.
7. HTTPS.
8. HTTP to HTTPS redirect.
9. Ansible connectivity.
10. First Ansible playbook execution.
11. Second idempotent execution.
12. VM2 reverse proxy.
13. VM3 reverse proxy.
14. Load balancing.
15. VM2 failure.
16. Continued `/app/` service through VM3.
17. VM2 recovery.
18. VM2 rejoining the load-balancing pool.
19. Final automated verification.

### Demo Video

> Add the Google Drive video link here after the final recording is uploaded.

```text
[Demo Video](PASTE-GOOGLE-DRIVE-LINK-HERE)
```

---

# 25. Repository

GitHub repository:

```text
https://github.com/thara-user/v7-devops-assignment
```

---

# 26. Conclusion

This project demonstrates a small but realistic DevOps infrastructure using containerized Ubuntu servers.

The implementation combines:

```text
Docker
   ↓
Linux
   ↓
Networking
   ↓
Firewall
   ↓
SSH Security
   ↓
Ansible Automation
   ↓
Nginx
   ↓
HTTPS
   ↓
Reverse Proxy
   ↓
Load Balancing
   ↓
Failover
   ↓
Recovery
   ↓
Automated Verification
```

The infrastructure was tested successfully, including container availability, firewall configuration, SSH security, HTTPS, Ansible automation, idempotency, reverse proxying, load balancing, backend failure, backend recovery, and automated verification.

**Assessment Status: Implementation Completed and Verified**

