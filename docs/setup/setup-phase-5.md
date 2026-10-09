# Phase 5: Configure the EC2 with Ansible

[← Phase 4](setup-phase-4.md) · [All phases](../../README.md#getting-started) · [Phase 6 →](setup-phase-6.md)

You need the EC2 from Phase 4 running (`terraform apply`).

## 1. Install Ansible and its AWS dependencies (in the project venv)

```bash
pip install ansible boto3 botocore
cd ansible
ansible-galaxy collection install -r requirements.yml
```

If Ansible warns that it's ignoring `ansible.cfg` because the directory is world-writable (common on WSL), run `chmod 755 .` and try again.

## 2. Store the EC2's GHCR token in Secrets Manager

Use a **separate** `read:packages` token from the one you gave the cluster. Terraform creates the secret empty and deletes it on `destroy`, so **repeat this step after every `terraform apply`**.

```bash
read -rsp "GHCR read:packages token (EC2): " GHCR_TOKEN; echo
aws secretsmanager put-secret-value --region eu-west-1 \
  --secret-id devops-portfolio/ghcr-token \
  --secret-string "$GHCR_TOKEN"
unset GHCR_TOKEN
```

## 3. Run the playbook

```bash
ansible-inventory --graph      # should list your EC2, found by its Project tag (no hardcoded IPs)
ansible-playbook playbook.yml  # installs Docker, logs in to GHCR, pulls and runs the image, health checks it

curl http://<instance-public-ip>/health
```

Running the playbook a second time should report almost no changes. That's idempotency in action.

## 4. Tear down

```bash
cd ../terraform
terraform destroy
```

✅ **Checkpoint:** the playbook's final "Confirm the app responds" task passes, `curl` from your machine returns `{"status":"ok"}`, and `terraform destroy` completes cleanly.

---

[← Phase 4](setup-phase-4.md) · [All phases](../../README.md#getting-started) · [Phase 6 →](setup-phase-6.md)
