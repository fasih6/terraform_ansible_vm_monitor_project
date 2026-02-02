# terraform_ansible_vm_monitor_project


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
