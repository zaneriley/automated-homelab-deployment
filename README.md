# Homelab Infrastructure Playbook

This is a set of configs designed for setting up and managing my homelab. Primarily, this is a set of Intel-based NUCS connected to a NAS. The configs do the following:

- Ubuntu auto-configs to initially set up machines with Ubuntu Server LTS.
- Ansible to bring machines to the latest server state
- Terraform to connect specific docker containers to publically accessible domain name (e.g yourhomelab.com)

While this is for my personal homelab, you might find some use from this if you:

* Don't want to set up your homelab (e.g. servers, software, dns, etc) manually each time
* You had your entire homelab get deleted and feel bad about it so you tell yourself you'll automate it but then it takes forever to remember all things you did to create your server in the first place but after a while you finally get something working
* Are interesting in learning more about idempotency, IaC, etc


## Prerequisites

Before you begin, ensure you have:

### Remote nodes
- Hardware you want to spin up to act as servers (i.e run the docker containers). In my case, Intel NUCs.
- Ubuntu Server 22 LTS already installed on above hardware, with a user called `ansible` and your ssh keys as authorized_keys on the NUC.

### Control node
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html) and [Terraformd](https://developer.hashicorp.com/terraform/install) installed
- Basic understanding of Ansible, Docker, and Unix/Linux systems.


## Setting up remote nodes

If you haven't already done so, set up your hardware with an operating system like Ubuntu Server LTS. The autoconfigs in this repo can be loaded on to a USB when reformating machines to do this automatically. If you have your machines set up, read on...


### Ansible
#### Inventory Configuration

You need to set up your own `inventory` file to tell ansible where your remote nodes are. Replace the example values with your specific configurations:

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

#### Vault Configuration (`vault.yml`)

Store sensitive information like passwords and SSH keys in `vault.yml`. Be sure to update this file with your specific data.

#### Note if you're using a private github repo! 

For using a private GitHub repository in this playbook, special attention is needed for SSH keys on your control node. You'll need to set up ssh forwarding on your control node.

**Setting up SSH Key**

1. **Create an SSH Key**: If you don't have an SSH key on your control node, generate one using `ssh-keygen`.
2. **Add SSH Key to GitHub**: Upload the generated SSH public key to your GitHub account under Settings > SSH and GPG keys.

**SSH Agent Forwarding**

SSH Agent Forwarding is used to securely use your SSH keys from the control node on the NUCs without physically copying them.

1. **Ensure SSH Agent is Running**: Start the SSH agent in the background using `eval $(ssh-agent -s)` and add your SSH key to the agent using `ssh-add`.
2. **Test SSH Agent Forwarding**: Test the setup by running `ssh -A ansible@remote-node-ip ssh -T git@github.com`. You should see a message indicating successful authentication but no shell access on GitHub.
3. **Configure Ansible**: Make sure your Ansible configuration supports SSH Agent Forwarding. This is often enabled by default in recent versions of Ansible.

### Running Playbooks

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


## Connecting specific docker containers to your domain name via Cloudflare

### Terraform

Ensure you have Terraform installed on your control node. You can run something like:

```bash
terraform -version
```
And you should see:
```
Terraform v1.6.6
on linux_amd64
```

Now that Terraform is installed on your machine, you can navigate to the directory and run `terraform init` to initialize your Terraform project. You should see a message like:
```bash
Terraform has been successfully initialized!
```

After that, continue with other Terraform commands like `terraform plan`, `terraform apply`, etc., to manage your infrastructure.