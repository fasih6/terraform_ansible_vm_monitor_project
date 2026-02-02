# Ansible VM Health Monitoring & Reporting

Automated VM health monitoring system that collects CPU, memory, and disk metrics from AWS EC2 instances and sends beautiful HTML email reports.

---

## 📁 Project Structure

```
ansible/
├── ansible.cfg                           # Ansible configuration
├── playbook.yaml                         # Main playbook (orchestrator)
├── collect_metrics.yaml                  # Metric collection playbook
├── send_report.yaml                      # Report generation & email playbook
├── inventory/
│   └── aws_ec2.yaml                      # AWS dynamic inventory configuration
├── group_vars/
│   └── all.yaml                          # Email configuration variables
└── templates/
    └── report_email_animated.html.j2     # HTML email template
```

---

## 🎯 What This Does

1. **Discovers EC2 Instances:** Automatically finds all running EC2 instances tagged with `Environment=dev`
2. **Collects Metrics:** Gathers CPU, memory, and disk usage from each instance
3. **Generates Report:** Creates a beautiful HTML report with visual progress bars and health indicators
4. **Sends Email:** Delivers the report via Gmail to specified recipients

---

## 📋 Prerequisites

### 1. System Requirements

**On your Ubuntu control machine:**

```bash
# Update system
sudo apt update

# Installing Ansible on Ubuntu

sudo apt update
sudo apt install software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible

# Install pip if not already installed
sudo apt install -y python3-pip

# Install latest boto3 (includes botocore)
pip3 install --upgrade boto3 botocore

# Install Ansible AWS collection
ansible-galaxy collection install amazon.aws
```

---

### 2. AWS Configuration

```bash
# Configure AWS credentials
aws configure

# Or manually create ~/.aws/credentials
mkdir -p ~/.aws
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
EOF

chmod 600 ~/.aws/credentials
```

**Required AWS Permissions:**
- `ec2:DescribeInstances`
- `ec2:DescribeInstanceStatus`
- `ec2:DescribeTags`

---

### 3. Gmail App Password

**⚠️ Important: You CANNOT use your regular Gmail password!**

**Steps to get Gmail App Password:**

1. Go to your Google Account: https://myaccount.google.com/
2. Enable **2-Factor Authentication** (if not already enabled)
3. Go to **Security** → **2-Step Verification** → **App passwords**
4. Generate a new app password for "Mail"
5. Copy the 16-character password (format: `xxxx xxxx xxxx xxxx`)
6. Add it to `group_vars/all.yaml`

---

### 4. SSH Key Setup

```bash
# Ensure you have the Terraform-generated SSH key
ls -la ../terraform/ans_master_1

# Set correct permissions
chmod 600 ../terraform/ans_master_1
```

---

## ⚙️ Configuration Files Explained

### **ansible.cfg**

Main Ansible configuration file:

```ini
[defaults]
inventory = ./inventory/aws_ec2.yaml    # Points to dynamic inventory
host_key_checking = False               # SSH usually checks the remote server’s fingerprint the first time you connect.Setting this to False disables the prompt.
remote_user = ubuntu                    # Default SSH user
gathering = smart                       # smart → only gathers facts if needed for a task.
deprecation_warnings = False            # Suppress deprecation warnings
retry_files_enabled = False             # By default, Ansible creates .retry files for failed hosts. False disables this

[ssh_connection]
pipelining = True                       # Normally, Ansible talks to your server over SSH by sending multiple commands for each task. With pipelining, Ansible combines some of these commands into one.
```

**Key Benefits:**
- ✅ Automatic AWS inventory discovery
- ✅ No SSH fingerprint prompts for new EC2s
- ✅ Faster playbook execution (pipelining)

---

### **inventory/aws_ec2.yaml**

AWS dynamic inventory configuration:

```yaml
plugin: amazon.aws.aws_ec2              # Use AWS EC2 inventory plugin
regions:
  - us-east-1                           # AWS region to query

filters:
  "tag:Environment": dev                # Only instances with Environment=dev tag
  instance-state-name: running          # Only running instances

keyed_groups:
  - key: tags.Environment               # Group instances by Environment tag
    prefix: tag_Environment_            # Creates group: tag_Environment__dev

compose:
  ansible_host: public_ip_address       # Use public IP for SSH connection
```

**How It Works:**
1. Queries AWS EC2 API for instances in `us-east-1`
2. Filters instances with `Environment=dev` tag and `running` state
3. Creates Ansible group `tag_Environment__dev`
4. Uses public IP addresses for SSH connections

**Test the inventory:**
```bash
# List all discovered hosts
ansible-inventory -i inventory/aws_ec2.yaml --list

# Ping all hosts
ansible tag_Environment__dev -m ping -i inventory/aws_ec2.yaml --private-key ../terraform/ans_master_1 -u ubuntu
```

---

### **group_vars/all.yaml**

Email configuration variables (applies to all hosts):

```yaml
smtp_server: "smtp.gmail.com"           # Gmail SMTP server
smtp_port: 587                          # SMTP port (STARTTLS)
email_user: "abc@gmail.com"             # Your Gmail address
email_pass: "xxxx xxxx xxxx xxxx"       # Gmail App Password (16 chars)
alert_recipient: "abc@gmail.com"        # Report recipient email
```

**Security Best Practice:**

Encrypt this file with Ansible Vault:

```bash
# Encrypt the file
ansible-vault encrypt group_vars/all.yaml

# Edit encrypted file
ansible-vault edit group_vars/all.yaml

# Run playbook with vault password
ansible-playbook playbook.yaml --ask-vault-pass
```

---

## 📊 Playbooks Explained

### **playbook.yaml** (Main Orchestrator)

```yaml
- import_playbook: collect_metrics.yaml  # Step 1: Collect metrics
- import_playbook: send_report.yaml      # Step 2: Send report
```

Simple orchestrator that runs playbooks in sequence.

---

### **collect_metrics.yaml** (Metric Collection)

**Purpose:** Collects CPU, memory, and disk metrics from all EC2 instances

**Flow:**

```
┌─────────────────────────────────────────┐
│ PLAY 1: Collect VM metrics              │
│ (runs on each EC2 instance)             │
└─────────────────┬───────────────────────┘
                  │
                  ▼
    ┌─────────────────────────────┐
    │ Install sysstat package     │
    └─────────────┬───────────────┘
                  │
                  ▼
    ┌─────────────────────────────┐
    │ Get CPU usage (mpstat)      │
    └─────────────┬───────────────┘
                  │
                  ▼
    ┌─────────────────────────────┐
    │ Get Memory usage (free)     │
    └─────────────┬───────────────┘
                  │
                  ▼
    ┌─────────────────────────────┐
    │ Get Disk usage (df)         │
    └─────────────┬───────────────┘
                  │
                  ▼
    ┌─────────────────────────────┐
    │ Store metrics as fact       │
    └─────────────────────────────┘

┌─────────────────────────────────────────┐
│ PLAY 2: Aggregate all metrics           │
│ (runs on localhost)                     │
└─────────────────┬───────────────────────┘
                  │
                  ▼
    ┌─────────────────────────────┐
    │ Collect all host_metrics    │
    │ from all EC2 instances      │
    └─────────────────────────────┘
```

**Metrics Collected:**

| Metric | Command | Example Output |
|--------|---------|----------------|
| **CPU** | `mpstat 1 1` | `12.45%` |
| **Memory** | `free` | `67.89%` |
| **Disk** | `df /` | `35%` |

**Data Structure:**

```yaml
all_metrics:
  - hostname: "ec2-54-227-124-143.compute-1.amazonaws.com"
    cpu: 12.45
    mem: 67.89
    disk: 35.0
  - hostname: "ec2-50-17-101-154.compute-1.amazonaws.com"
    cpu: 8.23
    mem: 54.32
    disk: 42.0
```

---

### **send_report.yaml** (Report Generation & Email)

**Purpose:** Generates HTML report and sends via email

**Flow:**

```
┌─────────────────────────────────────────┐
│ PLAY: Generate and send report          │
│ (runs on localhost)                     │
└─────────────────┬───────────────────────┘
                  │
                  ▼
    ┌─────────────────────────────┐
    │ Debug: Show collected       │
    │ metrics (for troubleshoot)  │
    └─────────────┬───────────────┘
                  │
                  ▼
    ┌─────────────────────────────┐
    │ Render HTML report using    │
    │ Jinja2 template             │
    │ → /tmp/vm_health_report.html│
    └─────────────┬───────────────┘
                  │
                  ▼
    ┌─────────────────────────────┐
    │ Send email via Gmail SMTP   │
    │ with HTML report as body    │
    └─────────────────────────────┘
```

**Email Report Features:**

- 📊 Summary statistics (average CPU, memory, disk)
- 📈 Visual progress bars for each metric
- 🎨 Color-coded health badges:
  - 🟢 **Healthy** (< 50%)
  - 🟡 **Warning** (50-80%)
  - 🔴 **Critical** (> 80%)
- 🕐 Timestamp of report generation
- 🔗 Clickable hostnames

---

### **templates/report_email_animated.html.j2**

Beautiful HTML email template with:

- Responsive design
- Professional styling
- Animated progress bars
- Health status badges
- Summary statistics at the top

**Template Variables Used:**

- `collected_metrics` - List of all VM metrics
- `timestamp` - Report generation time

**Jinja2 Logic:**

```jinja2
{% for vm in collected_metrics %}
  <tr>
    <td>{{ vm.hostname }}</td>
    <td>
      {{ vm.cpu }}%
      <div class="bar" style="width: {{ vm.cpu }}%"></div>
      {% if vm.cpu|float < 50 %}
        <span class="badge healthy">Healthy</span>
      {% elif vm.cpu|float < 80 %}
        <span class="badge warning">Warning</span>
      {% else %}
        <span class="badge critical">Critical</span>
      {% endif %}
    </td>
    <!-- Similar for memory and disk -->
  </tr>
{% endfor %}
```

---

## 🚀 Usage

### **Basic Usage**

```bash
# Navigate to ansible directory
cd ansible/

# Run the complete monitoring workflow
ansible-playbook playbook.yaml \
  -i inventory/aws_ec2.yaml \
  --private-key ../terraform/ans_master_1 \
  -u ubuntu
```

---

### **Step-by-Step Execution**

```bash
# Step 1: Test dynamic inventory
ansible-inventory -i inventory/aws_ec2.yaml --list

# Step 2: Test connectivity
ansible tag_Environment__dev -m ping \
  -i inventory/aws_ec2.yaml \
  --private-key ../terraform/ans_master_1 \
  -u ubuntu

# Step 3: Run metric collection only
ansible-playbook collect_metrics.yaml \
  -i inventory/aws_ec2.yaml \
  --private-key ../terraform/ans_master_1 \
  -u ubuntu

# Step 4: Run complete workflow
ansible-playbook playbook.yaml \
  -i inventory/aws_ec2.yaml \
  --private-key ../terraform/ans_master_1 \
  -u ubuntu
```

---

### **Using Shorter Command (ansible.cfg handles defaults)**

Since `ansible.cfg` sets the inventory path, you can use:

```bash
# Simply run (inventory path from ansible.cfg)
ansible-playbook playbook.yaml --private-key ../terraform/ans_master_1
```

Or create a shell script `run.sh`:

```bash
#!/bin/bash
ansible-playbook playbook.yaml \
  --private-key ../terraform/ans_master_1 \
  -u ubuntu
```

```bash
chmod +x run.sh
./run.sh
```

---

## 📧 Email Report Output

**Subject:**
```
📊 VM Health Report - 2026-02-02 14:30:45
```

**Body:** Beautiful HTML report showing:

```
┌─────────────────────────────────────────────────────────┐
│           📊 Consolidated VM Health Report              │
├─────────────────────────────────────────────────────────┤
│  📅 2 VMs | 🔥 Avg CPU: 10.34% | 📥 Avg Mem: 61.11% | │
│  📦 Avg Disk: 38.50%                                    │
├──────────────┬──────────┬─────────────┬────────────────┤
│   Hostname   │   CPU    │   Memory    │     Disk       │
├──────────────┼──────────┼─────────────┼────────────────┤
│ ec2-54-...   │  12.45%  │   67.89%    │    35.0%       │
│              │ ▓▓▓░░░   │ ▓▓▓▓▓▓░░    │   ▓▓▓░░        │
│              │ Healthy  │  Warning    │   Ample        │
├──────────────┼──────────┼─────────────┼────────────────┤
│ ec2-50-...   │   8.23%  │   54.32%    │    42.0%       │
│              │ ▓▓░░░░   │ ▓▓▓▓▓░░░    │   ▓▓▓▓░        │
│              │ Healthy  │  Warning    │   Monitor      │
└──────────────┴──────────┴─────────────┴────────────────┘
         ⏱️ Report Generated on: 2026-02-02 14:30:45
```

---


## 📊 Performance Optimization

### **1. Cache Inventory**

Add to `ansible.cfg`:

```ini
[inventory]
cache = yes
cache_plugin = jsonfile
cache_connection = /tmp/ansible_inventory_cache
cache_timeout = 300  # 5 minutes
```

**Benefit:** Reduces AWS API calls, faster playbook runs

---

### **2. SSH Connection Multiplexing**

Already configured in `ansible.cfg`:

```ini
[ssh_connection]
pipelining = True
```

Add for even better performance:

```ini
[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
control_path = /tmp/ansible-ssh-%%h-%%p-%%r
```

**Benefit:** Reuses SSH connections, 2-3x faster execution

---

### **3. Parallel Execution**

Collect metrics from multiple VMs simultaneously:

Edit `collect_metrics.yaml`:

```yaml
- name: Collect VM metrics
  hosts: tag_Environment__dev
  become: true
  gather_facts: true
  strategy: free        # ← Add this for parallel execution
  tasks:
    # ... rest of tasks
```

**Benefit:** Processes VMs in parallel instead of sequentially

---

### **4. Fact Caching**

Add to `ansible.cfg`:

```ini
[defaults]
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 3600  # 1 hour
```

**Benefit:** Caches gathered facts, faster subsequent runs

---

## 📈 Monitoring Best Practices

### **1. Retention & Archiving**

```bash
# Archive old reports
mkdir -p /var/log/vm-reports
cp /tmp/vm_health_report.html "/var/log/vm-reports/report-$(date +%Y%m%d-%H%M%S).html"

# Clean up old reports (keep last 30 days)
find /var/log/vm-reports -name "report-*.html" -mtime +30 -delete
```

Add to `send_report.yaml`:

```yaml
- name: Archive report
  copy:
    src: /tmp/vm_health_report.html
    dest: "/var/log/vm-reports/report-{{ ansible_date_time.iso8601_basic_short }}.html"
  delegate_to: localhost
```

---

### **2. Alerting Thresholds**

Create `group_vars/thresholds.yaml`:

```yaml
cpu_warning: 50
cpu_critical: 80
mem_warning: 70
mem_critical: 85
disk_warning: 75
disk_critical: 90
```

Use in playbooks for conditional alerts.

---

### **3. Logging**

Enable Ansible logging in `ansible.cfg`:

```ini
[defaults]
log_path = /var/log/ansible-vm-monitoring.log
```

```bash
# View logs
tail -f /var/log/ansible-vm-monitoring.log

# Rotate logs
sudo logrotate -f /etc/logrotate.d/ansible
```

---

### **4. Health Checks**

Create a simple health check script:

```bash
#!/bin/bash
# check-monitoring.sh

# Check if last run was successful
if tail -1 /var/log/ansible-vm-monitoring.log | grep -q "failed=0"; then
    echo "✅ Monitoring is healthy"
    exit 0
else
    echo "❌ Monitoring has failures"
    exit 1
fi
```

---

## 🔐 Security Best Practices

### **1. Encrypt Sensitive Variables**

```bash
# Encrypt group_vars/all.yaml
ansible-vault encrypt group_vars/all.yaml

# Run playbook with vault password
ansible-playbook playbook.yaml --ask-vault-pass

# Or use password file
echo "my-vault-password" > .vault_pass
chmod 600 .vault_pass
echo ".vault_pass" >> .gitignore

# Run with password file
ansible-playbook playbook.yaml --vault-password-file .vault_pass
```

---

### **2. Secure SSH Keys**

```bash
# Proper permissions
chmod 600 ../terraform/ans_master_1
chmod 644 ../terraform/ans_master_1.pub

# Never commit private keys
echo "*.pem" >> .gitignore
echo "ans_master_1" >> .gitignore
```

---

### **3. Limit AWS Permissions**

Create IAM user with minimal permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeTags"
      ],
      "Resource": "*"
    }
  ]
}
```

---

### **4. Secure Email Credentials**

```bash
# Use environment variables instead of hardcoding
export SMTP_USER="abc@gmail.com"
export SMTP_PASS="xxxx xxxx xxxx xxxx"

# Reference in playbook
email_user: "{{ lookup('env', 'SMTP_USER') }}"
email_pass: "{{ lookup('env', 'SMTP_PASS') }}"
```

---

## 📚 Additional Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible AWS Guide](https://docs.ansible.com/ansible/latest/scenario_guides/guide_aws.html)
- [AWS EC2 Dynamic Inventory](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html)
- [Ansible Vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- [Gmail SMTP Settings](https://support.google.com/mail/answer/7126229)

---

## 🎓 Learning Path

1. ✅ **Basic Setup:** Get dynamic inventory working
2. ✅ **Metric Collection:** Understand how metrics are gathered
3. ✅ **Report Generation:** Customize HTML template
4. ✅ **Email Delivery:** Configure Gmail App Password
5. 🔄 **Automation:** Set up cron jobs
6. 🔐 **Security:** Implement Ansible Vault
7. 📊 **Monitoring:** Add custom metrics
8. 🚨 **Alerting:** Implement conditional alerts

---

## 🔄 Workflow Summary

```
┌─────────────────────────────────────────────────────────┐
│  1. Terraform creates EC2 instances                     │
│     (with Environment=dev tag)                          │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  2. Ansible queries AWS API                             │
│     (discovers instances via dynamic inventory)         │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  3. collect_metrics.yaml runs                           │
│     - SSH to each EC2 instance                          │
│     - Collect CPU, memory, disk metrics                 │
│     - Store in host_metrics fact                        │
│     - Aggregate all metrics in all_metrics              │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  4. send_report.yaml runs                               │
│     - Render HTML template with metrics                 │
│     - Send email via Gmail SMTP                         │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│  5. Email received with beautiful HTML report           │
│     ✅ Success!                                         │
└─────────────────────────────────────────────────────────┘
```

---
