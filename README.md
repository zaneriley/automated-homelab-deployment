# Homelab Infrastructure Playbook

This is a set of Ansible playbooks designed for setting up and managing a network of Intel NUCs to run docker applications. It focuses on deploying a range of Docker containers on each NUC, while maintaining a common infrastructure. While this is for my personal homelab, you might find some use from this if you:

* Don't want to set up your docker machines manually each time
* You had your entire homelab get deleted and feel bad about it so you tell yourself you'll automate it but then it takes forever to remember all things you did to create your server in the first place but after a while you finally get something working
* Are interesting in learning more about idempotency, IaC, etc

## Prerequisites

Before you begin, ensure you have:

- The hardware you want to spin up to run the docker containers. In my case, Intel NUCs.
- Ubuntu Server 22 LTS already installed with a user called `ansible` and your ssh keys as authorized_keys on the NUC.
- Ansible on the control node (the machine dispatching Ansible commands).
- Docker and Docker Compose installed.
- Basic understanding of Ansible, Docker, and Unix/Linux systems.


## Inventory Configuration

The `inventory` file is critical in defining the nodes. Replace the example values with your specific configurations:

```ini
[nucs]
nuc1 ansible_host=YOUR_NUC1_IP ansible_user=ansible github_repo="YOUR_GITHUB_REPO_TO_YOUR_DOCKER_STACK" homelab_srv_folder="/path/to/srv"
nuc2 ansible_host=YOUR_NUC2_IP ansible_user=ansible github_repo="YOUR_GITHUB_REPO_TO_YOUR_DOCKER_STACK" homelab_srv_folder="/path/to/srv"

[nas]
NAS ansible_host=YOUR_NAS_IP

[nas:vars]
backup_server_path="/path/to/backups"
media_server_path="/path/to/media"

[nucs:vars]
ansible_ssh_private_key_file="~/.ssh/id_rsa"
backup_mount_dir="/path/to/mnt/backups"
media_mount_dir="/path/to/media"
```

## Vault Configuration (`vault.yml`)

Store sensitive information like passwords and SSH keys in `vault.yml`. Be sure to update this file with your specific data.

## Playbook Details

### Set Up Docker and Homelab Dependencies (`setup.yml`)

This section involves tasks like package updates, system configurations, and preparing for Docker usage.

### Connecting to NAS

Ensures NAS connectivity via NFS by mounting NFS shares for media and backups.

### Setting Up Homelab Docker Stack

Configures necessary directories, SSH settings, and clones your Docker configuration from GitHub.

### Reboot Management

Checks for and manages system reboots post-update, including sending notifications to Discord

## Note if you're using a private github repo! 

For using a private GitHub repository in this playbook, special attention is needed for SSH keys on your control node. You'll need to set up ssh forwarding on your control node.

### Setting up SSH Key

1. **Create an SSH Key**: If you don't have an SSH key on your control node, generate one using `ssh-keygen`.
2. **Add SSH Key to GitHub**: Upload the generated SSH public key to your GitHub account under Settings > SSH and GPG keys.

### SSH Agent Forwarding

SSH Agent Forwarding is used to securely use your SSH keys from the control node on the NUCs without physically copying them.

1. **Ensure SSH Agent is Running**: Start the SSH agent in the background using `eval $(ssh-agent -s)` and add your SSH key to the agent using `ssh-add`.
2. **Test SSH Agent Forwarding**: Test the setup by running `ssh -A ansible@remote-node-ip ssh -T git@github.com`. You should see a message indicating successful authentication but no shell access on GitHub.
3. **Configure Ansible**: Make sure your Ansible configuration supports SSH Agent Forwarding. This is often enabled by default in recent versions of Ansible.

## Running Playbooks

You'll run these playbooks from the control node. 

First run the setup playbook :

```bash
ansible-playbook -i inventory setup.yml
```

Then you'll run the backup playbook to set up the backup infra.
```bash
ansible-playbook -i inventory backup.yml
```

Lastly, you'll want to set the backups on a schedule. Here’s how to do it:

```bash
ansible-playbook scheduler.yml
```

This will establish a cron job on the control node to run your backup playbook at the desired time.
