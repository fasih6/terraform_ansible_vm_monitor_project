#cloud-config
users:
  - default
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh-authorized-keys:
      - ${public_key}   # <-- THIS IS THE TEMPLATE VARIABLE

package_update: true
packages:
  - python3
  - docker.io

runcmd:
  - systemctl enable docker
  - systemctl start docker
