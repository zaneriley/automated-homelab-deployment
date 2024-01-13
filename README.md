# Homelab Infrastructure Playbook

This is a set of Ansible playbooks and Terraform configurations to automate setting up and managing my homelab environment.

## Overview

The playbooks and configs here allow you to:

* Set up Ubuntu Server LTS on mini-pcs using auto-configurations. 
* Utilize Ansible to manage server states and perform nightly backups
* Use Terraform to connect Docker containers to publicly accessible domain names (e.g., yourhomelab.com)

While this is for my personal homelab, you might find some use from this if you:

* Don't want to set up your homelab (e.g. servers, software, dns, etc) manually each time
* You had your entire homelab get deleted and feel bad about it so you tell yourself you'll automate it but then it takes forever to remember all things you did to create your server in the first place but after a while you finally get something working
* Are interesting in learning more about idempotency, IaC, etc

## Architecture

The main components are:

- **Remote nodes**: The physical machines (like Intel NUCs) that act as servers and run your services. Each remote node should have a matching git repository where you store your docker configs. For example. I have 1 nuc that handles home automation, document tracking and photo sharing for my family. Another nuc serves as a media and game server. This is not cloning the same remote node and load balacing them.

- **Control node**: The machine you use to control the remote nodes using Ansible/Terraform. This can be any Mac or Unix machine (no Windows, sorry!)

- **NAS**: Network attached storage for backups. We will back up each nuc's persistent docker container volumes here.

## Getting Started

This code is provided as is. To use this repo for your homelab:

1. Install Ubuntu Server on your remote nodes. 

2. On the control node:
   - Install Ansible and Terraform 
   - Clone this repo, or fork this and clone your own repo.
   - Configure Ansible inventory/variables
   - Run the Ansible playbooks to configure the remote nodes
   - Use Terraform to connect services to your domain

3. Configure recurring backups with Ansible

OR, you can look through the [Ansible](/ansible) or [Terraform](/terraform) configs and do each step manually, if you think this is overkill for your setup.

## Usage

**Ansible Playbooks**

The main Ansible playbooks are:

- `setup.yml`: Initial configuration of remote nodes. This brings a new machine to the last current server state.
- `backup.yml`: Configure backups to NAS 
- `scheduler.yml`: Schedule recurring backups

## Setting up remote nodes

If you haven't already done so, set up your hardware with an operating system like Ubuntu Server LTS. The autoconfigs in this repo can be loaded on to a USB when reformating machines to do this automatically. If you have your machines already set up, read on...

## Setting up the control node
Clone this repository to your control node:
```bash
git@github.com:zaneriley/homelab-infrastructure-setup.git
cd homelab-infrastructure-setup
```

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


#### Note on Private GitHub Repos

If your remote nodes pull configs from a private GitHub repo, special steps are needed for SSH keys. 

It is insecure to copy your SSH keys to every node. Instead, use SSH agent forwarding on the control node. When you SSH from a control node to a remote node, you'll bring your keys with you.

**On the Control Node**


2. Start the SSH agent and add your key: If you don't have one, google how to make one and add it to github.

    ```
    eval $(ssh-agent -s)
    ssh-add ~/.ssh/id_rsa
    ```

4. Test SSH agent forwarding:

    ```
    ssh -A ansible@remote_node_ip ssh -T git@github.com
    ```

    You should get a message about successful auth without a shell.

5. Enable agent forwarding in Ansible config.

Now Ansible can clone private repos on remote nodes using your SSH key on the control node. Keys are not copied to each node.

**Do Not**

- Copy keys to each node. Keep keys only on the control node.
- Add node keys to GitHub. Use only your control node key.

This is more secure than spreading keys across all nodes.

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