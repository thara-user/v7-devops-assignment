#!/bin/bash

set -u

PASS=0
FAIL=0

pass() {
    echo "✅ PASS: $1"
    PASS=$((PASS+1))
}

fail() {
    echo "❌ FAIL: $1"
    FAIL=$((FAIL+1))
}

echo "======================================"
echo " V7 DEVOPS AUTOMATED VERIFICATION"
echo "======================================"

echo
echo "1. Docker containers"
for vm in vm1 vm2 vm3; do
    if docker inspect -f '{{.State.Running}}' "$vm" 2>/dev/null | grep -q true; then
        pass "$vm is running"
    else
        fail "$vm is not running"
    fi
done

echo
echo "2. Docker restart policy"
for vm in vm1 vm2 vm3; do
    policy=$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' "$vm" 2>/dev/null)
    if [ "$policy" = "unless-stopped" ]; then
        pass "$vm restart policy = unless-stopped"
    else
        fail "$vm restart policy is $policy"
    fi
done

echo
echo "3. Firewall policy"
for vm in vm1 vm2 vm3; do
    policy=$(docker exec "$vm" iptables -S INPUT 2>/dev/null | head -1)

    if echo "$policy" | grep -q 'DROP'; then
        pass "$vm INPUT default policy DROP"
    else
        fail "$vm INPUT policy is not DROP"
    fi
done

echo
echo "4. SSH service"
for vm in vm1 vm2 vm3; do
    if docker exec "$vm" pgrep sshd >/dev/null 2>&1; then
        pass "$vm SSH running"
    else
        fail "$vm SSH not running"
    fi
done

echo
echo "5. Nginx service"
for vm in vm1 vm2 vm3; do
    if docker exec "$vm" pgrep nginx >/dev/null 2>&1; then
        pass "$vm Nginx running"
    else
        fail "$vm Nginx not running"
    fi
done

echo
echo "6. Nginx configuration"
for vm in vm1 vm2 vm3; do
    if docker exec "$vm" nginx -t >/dev/null 2>&1; then
        pass "$vm Nginx configuration"
    else
        fail "$vm Nginx configuration"
    fi
done

echo
echo "7. HTTPS"
if curl -ksf https://public.vm1.local >/dev/null; then
    pass "VM1 HTTPS works"
else
    fail "VM1 HTTPS failed"
fi

echo
echo "8. HTTP -> HTTPS redirect"
redirect=$(curl -sI http://public.vm1.local | grep -i '^Location:')

if echo "$redirect" | grep -q 'https://public.vm1.local'; then
    pass "HTTP redirects to HTTPS"
else
    fail "HTTP HTTPS redirect failed"
fi

echo
echo "9. VM2 reverse proxy"
if curl -ks https://public.vm1.local/vm2/ | grep -q 'Hostname: vm2'; then
    pass "VM1 -> VM2 proxy"
else
    fail "VM1 -> VM2 proxy"
fi

echo
echo "10. VM3 reverse proxy"
if curl -ks https://public.vm1.local/vm3/ | grep -q 'Hostname: vm3'; then
    pass "VM1 -> VM3 proxy"
else
    fail "VM1 -> VM3 proxy"
fi

echo
echo "11. Load balancing"
VM2_COUNT=0
VM3_COUNT=0

for i in {1..10}; do
    HOST=$(curl -ks https://public.vm1.local/app/ | grep -o 'Hostname: vm[23]' | head -1)

    if echo "$HOST" | grep -q 'vm2'; then
        VM2_COUNT=$((VM2_COUNT+1))
    elif echo "$HOST" | grep -q 'vm3'; then
        VM3_COUNT=$((VM3_COUNT+1))
    fi
done

echo "VM2 responses: $VM2_COUNT"
echo "VM3 responses: $VM3_COUNT"

if [ "$VM2_COUNT" -gt 0 ] && [ "$VM3_COUNT" -gt 0 ]; then
    pass "Load balancing reaches both VM2 and VM3"
else
    fail "Load balancing did not reach both VMs"
fi

echo
echo "12. Ansible ping"

cd ansible

if ansible all -m ping --ask-vault-pass; then
    pass "Ansible can reach all VMs"
else
    fail "Ansible ping failed"
fi

echo
echo "======================================"
echo " RESULTS"
echo "======================================"
echo "PASSED: $PASS"
echo "FAILED: $FAIL"

if [ "$FAIL" -eq 0 ]; then
    echo
    echo "🎉 ALL AUTOMATED CHECKS PASSED"
    exit 0
else
    echo
    echo "⚠️ SOME CHECKS FAILED"
    exit 1
fi
