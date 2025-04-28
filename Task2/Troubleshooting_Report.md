# Troubleshooting: `internal.example.com` – “host not found”

_A one-person lab that recreates a DNS outage, tests four hypotheses, and
finally restores service.  Screenshot placeholders are HTML comments:
replace each with the real PNG in `/screenshots/`._

---

## 0. Lab Environment

 Distro          
|
 Ubuntu 24.04 LTS inside 
**
WSL 2
**
|
|
 Kernel          
|
 5.15.x (WSL default)                    
|
|
 Test Webserver  
|
`python3 -m http.server 80`
|
|
 Target FQDN     
|
`internal.example.com`
 (loopback alias) 
|

---

## 1. Build the Mini-Lab

~~~bash
# start a simple HTTP server
mkdir -p ~/lab && cd ~/lab
echo "Hello from internal.example.com" > index.html
sudo python3 -m http.server 80 &
# create initial hostname mapping
echo "127.0.0.1  internal.example.com" | sudo tee -a /etc/hosts
~~~

Everything works at this point.

Now **break** DNS on purpose:

~~~bash
sudo sed -i '/internal\.example\.com/d' /etc/hosts
~~~

---

## 2. Reproduce the Failure

~~~bash
ping -c2 internal.example.com          # Name or service not known
curl -I http://internal.example.com    # curl: (6) Could not resolve host
~~~

<!-- screenshot: screenshots/01_problem_statement.png -->

![01_problem_statement](https://github.com/user-attachments/assets/23f93bc3-ebf6-4b28-81f0-5c8cc42d8148)

---

## 3. Hypothesis-Driven Troubleshooting

### Stage 1 – Service crash?

~~~bash
sudo ss -lntp | grep ':80'             # python on 0.0.0.0:80
curl -I http://127.0.0.1               # HTTP/1.0 200 OK
~~~

<!-- screenshot: screenshots/02_service_healthy.png -->
![02_service_healthy](https://github.com/user-attachments/assets/79713af4-aa71-4feb-8556-2a72629fe32d)


_Result_: server healthy → **Hypothesis A rejected**

---

### Stage 2 – Firewall block?

~~~bash
sudo iptables -L -n | grep ':80'       # no rules
sudo ufw status                        # inactive
~~~

<!-- screenshot: screenshots/03_no_firewall_block.png -->
![03_no_firewall_block](https://github.com/user-attachments/assets/bb681d58-bfc7-48dc-b4ed-6d46f25d749e)


_Result_: no firewall rules → **Hypothesis B rejected**

---

### Stage 3 – Routing / ACL?

~~~bash
tracepath -p 80 127.0.0.1 | head -3    # direct
nc -vz 127.0.0.1 80                    # succeeded
~~~

<!-- screenshot: screenshots/04_network_path_ok.png -->
![04_network_path_ok](https://github.com/user-attachments/assets/dce6b17c-b05a-4e20-999f-4806147696da)


_Result_: network path fine → **Hypothesis C rejected**

---

### Stage 4 – DNS / Resolver problem

~~~bash
cat /etc/resolv.conf                   # shows 10.255.255.254
dig internal.example.com               # NXDOMAIN
dig @8.8.8.8 internal.example.com      # NXDOMAIN
sudo resolvectl flush-caches 2>/dev/null || true
dig internal.example.com               # still NXDOMAIN
~~~

<!-- screenshot: screenshots/05_dns_fails_everywhere.png -->
![05_dns_fails_everywhere](https://github.com/user-attachments/assets/0de71c92-83b6-4a99-b0c5-dba21423b558)


![06_Flush_local_cache ](https://github.com/user-attachments/assets/ff14e3a8-0a35-4d15-a769-f66204a5a17d)


_Result_: No DNS server returns a record → **DNS layer confirmed**

---

### Stage 5 – Wrong fix attempt

~~~bash
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
dig internal.example.com               # still NXDOMAIN
~~~

<!-- screenshot: screenshots/06_wrong_fix_didnt_help.png -->

![07_Changing_upstream_resolver_didn’t_help](https://github.com/user-attachments/assets/e1be8496-a803-4f5f-9913-ff31da6c850b)


_Result_: Upstream change ineffective → record truly absent

---

### Stage 6 – Final fix (`/etc/hosts` override)

~~~bash
echo "127.0.0.1  internal.example.com" | sudo tee -a /etc/hosts
getent hosts internal.example.com      # 127.0.0.1
curl -I http://internal.example.com    # HTTP/1.0 200 OK
~~~

<!-- screenshot: screenshots/07_final_fix_success.png -->

![08_final_fix_success](https://github.com/user-attachments/assets/5d095dc4-b4e5-47fe-adc0-05094553a143)


_Result_: Service restored – **root cause resolved**


