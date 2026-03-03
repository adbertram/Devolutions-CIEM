# CI/CD automation

**Source URL:** https://docs.devolutions.net/pam/concepts/cicd-automation/

---

CI/CD automation
is a key DevOps practice that streamlines software delivery by automating the integration and deployment processes. In the context of privileged access and credential management, CI/CD pipelines often require access to APIs and services, which traditionally relied on hard-coded credentials in scripts or configuration files. This practice poses serious security risks.
By integrating secure vaults and automated credential injection, CI/CD automation replaces static credentials with dynamic, centrally managed ones. This ensures that credentials are never exposed in source code or configuration files. Products like Devolutions PAM and Devolutions Server can facilitate this process by brokering access to secrets and injecting them only at runtime.
This approach improves security, simplifies
credential rotation
, and helps organizations enforce
least privilege
policies in their DevOps environments.
Supported tools
Ansible
Kubernetes
Terraform
CI/CD automation aliases
Continuous integration/continuous deployment automation
CI/CD credential management
DevOps pipeline secrets injection
Related topics
Password management
External PAM integrations
Scripts
Share your feedback

---

*Downloaded on: 2026-02-18 13:08:23*