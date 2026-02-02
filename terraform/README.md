
# Terraform AWS EC2 Infrastructure

This Terraform configuration automatically provisions AWS EC2 instances for the VM health monitoring project.

---

## 📁 Structure

```
terraform/
├── main.tf                    # EC2 instance resources
├── variables.tf               # Input variables
├── cloud-init.yaml.tpl        # Cloud-init template for instance bootstrapping
├── ans_master_1               # Private SSH key (keep secure!)
└── ans_master_1.pub           # Public SSH key
```

---

## 🎯 What This Does

1. **Provisions EC2 Instances:** Creates multiple Ubuntu EC2 instances in AWS
2. **Automatic Configuration:** Uses cloud-init to:
   - Create `ubuntu` user with passwordless sudo
   - Install Python3 and Docker
   - Configure SSH key authentication
   - Enable and start Docker service
3. **Tagging:** Tags instances for Ansible dynamic inventory discovery

---

## 📋 Prerequisites

### 1. AWS Account Setup

```bash
# Configure AWS credentials
aws configure

# Or manually create ~/.aws/credentials
[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
```

### 2. Required Tools

```bash
terraform
aws cli
```

### 3. SSH Key Pair

```bash
# Generate SSH key pair (if you don't have one)
ssh-keygen -t rsa -b 4096 -f ans_master_1 -N ""

# This creates:
# - ans_master_1      (private key)
# - ans_master_1.pub  (public key)
```

---

## ⚙️ Configuration Files Explained

### **main.tf**

Defines the EC2 instance resources:

```hcl
resource "aws_instance" "web" {
  count         = var.instance_count           # Number of instances to create
  ami           = "ami-0b6c6ebed2801a5cb"      # Ubuntu 24.04 LTS (us-east-1)
  instance_type = "t3.micro"                   # Instance type (Free tier eligible)
  vpc_security_group_ids = ["sg-0cffc6ab..."]  # Security group ID
  
  # Bootstrap script
  user_data = templatefile("${path.module}/cloud-init.yaml.tpl", {
    public_key = file("${path.module}/ans_master_1.pub")
  })
  
  # Tags for identification
  tags = {
    Name        = "web-${count.index + 1}"     # web-1, web-2, etc.
    Environment = "dev"                         # Used by Ansible inventory
    Role        = "web"
  }
}
```

**Key Components:**
- **AMI:** Ubuntu 24.04 LTS image for us-east-1 region
- **Instance Type:** t3.micro (1 vCPU, 1GB RAM)
- **Security Group:** Must allow SSH (port 22) from your IP
- **Tags:** `Environment=dev` is used by Ansible for dynamic inventory

---

### **variables.tf**

Defines input variables:

```hcl
variable "region" {
  default = "us-east-1"
}

variable "instance_count" {
  default = 2                # Change this to create more/fewer instances
}
```

**Customization:**
```bash
# Override default instance count
terraform apply -var="instance_count=5"
```

---

### **cloud-init.yaml.tpl**

Bootstrap script that runs on first instance launch:

```yaml
#cloud-config
users:
  - default
  - name: ubuntu                      # Create ubuntu user
    sudo: ALL=(ALL) NOPASSWD:ALL      # Grant passwordless sudo
    shell: /bin/bash
    ssh-authorized-keys:
      - ${public_key}                 # Inject SSH public key

package_update: true                  # Update package lists
packages:
  - python3                           # Required for Ansible
  - docker.io                         # Docker for containerization

runcmd:
  - systemctl enable docker           # Enable Docker on boot
  - systemctl start docker            # Start Docker service
```

**What Happens on Boot:**
1. Creates `ubuntu` user with your SSH key
2. Updates apt package lists
3. Installs Python3 (required by Ansible)
4. Installs and starts Docker
5. Configures passwordless sudo

---

## 🚀 Usage


### **4. Verify Instances**

```bash
# List created instances
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=dev" \
  --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Or use Terraform output
terraform show
```

---

### **5. Test SSH Access**

```bash
# Get instance public IP from AWS console or:
terraform show | grep public_ip

# SSH to instance
ssh -i ans_master_1 ubuntu@
```

---


Find Ubuntu AMIs at: https://cloud-images.ubuntu.com/locator/ec2/




---

## 🛡️ Security Considerations

### **x. Security Group Configuration**

⚠️ **Current setup uses existing security group:** `sg-0cffc6ab3061c2c9b`

**Ensure it allows:**
```
Inbound Rules:
- SSH (22) from YOUR_IP/32
- HTTP (80) from 0.0.0.0/0 (if running web services)

Outbound Rules:
- All traffic (0.0.0.0/0)
```


### **x. SSH Key Security**

```bash
# Secure private key
chmod 600 ans_master_1

# Never commit private key to git!
echo "ans_master_1" >> .gitignore
```

---

## 🧹 Cleanup

### **Destroy All Resources**

```bash
# Preview what will be destroyed
terraform plan -destroy

# Destroy infrastructure
terraform destroy
```
---


**Workflow:**
1. Terraform creates EC2 instances with `Environment=dev` tag
2. Ansible dynamic inventory queries AWS for instances with this tag
3. Ansible runs health monitoring playbooks on discovered instances

---


## 📚 Additional Resources

- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [Ubuntu EC2 AMI Finder](https://cloud-images.ubuntu.com/locator/ec2/)
- [AWS EC2 Pricing](https://aws.amazon.com/ec2/pricing/)

---



## 📝 Notes

- **AMI ID:** `ami-0b6c6ebed2801a5cb` is for **Ubuntu 24.04 LTS** in **us-east-1**
- **Instance Tags:** The `Environment=dev` tag is crucial for Ansible inventory filtering
- **Cloud-init:** Bootstrap process takes 1-2 minutes after instance launch
- **SSH Key:** Keep `ans_master_1` private key secure and never commit to version control

---

