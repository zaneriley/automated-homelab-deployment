# Automated Homelab Deployment with Ansible and Terraform

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

## Getting Started
[You can read the docs here.](https://automated-homelab-deployment.vercel.app/)

