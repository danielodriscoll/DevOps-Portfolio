# Phase 4: AWS infrastructure with Terraform

[← Phase 3](setup-phase-3.md) · [All phases](../../README.md#getting-started) · [Phase 5 →](setup-phase-5.md)

> ⚠️ **This creates real, billable resources**: a `t3.micro` EC2 (billed hourly) and a Secrets Manager secret (about $0.40/month). Before you start, set an **AWS Budget alert** (I used $1), and run `terraform destroy` at the end of every session.

## 1. Set up AWS access safely (one time)

- Turn on MFA for the root user, then stop using root.
- In IAM, create a dedicated user (e.g. `terraform-user`) with an access key. Give it only what this project needs: EC2, the S3 state bucket, IAM roles and instance profiles (including `iam:PassRole`) and Secrets Manager. Start narrow and widen only when Terraform tells you a permission is missing.
- Configure the CLI with that user. **Set the default region to `eu-west-1`**: the Terraform config takes its region from here, and the Ansible inventory in Phase 5 looks there.

```bash
aws configure                 # access key, secret key, region: eu-west-1, output: json
aws sts get-caller-identity   # should show terraform-user, NOT root
```

## 2. Create the remote state bucket (one time)

S3 bucket names are globally unique. The `sed` in Phase 2 already put your username into the bucket name in `terraform/bootstrap/main.tf` and `terraform/backend.tf`. If the name is still taken, change it in **both** files.

```bash
cd terraform/bootstrap
terraform init
terraform apply               # creates a versioned, encrypted, private S3 bucket
cd ..
```

## 3. Supply your private values

SSH and HTTP are locked to your own IP. These values go in `terraform.tfvars`, which is gitignored.

```bash
# Create an SSH key if you don't already have one
[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519

cat > terraform.tfvars <<EOF
my_ip          = "$(curl -s https://checkip.amazonaws.com)/32"
ssh_public_key = "$(cat ~/.ssh/id_ed25519.pub)"
EOF

git check-ignore terraform.tfvars    # must print the filename, which proves it won't be committed
```

Only the **public** key (`.pub`) ever goes in this file.

## 4. Deploy

```bash
terraform init            # connects to the S3 backend
terraform plan            # read it before applying
terraform apply

terraform output instance_public_ip
ssh -i ~/.ssh/id_ed25519 ec2-user@<instance-public-ip>
```

If SSH suddenly times out on a later day, your home IP has probably changed. Regenerate `terraform.tfvars` (step 3) and run `terraform apply` again; it updates the firewall rule in place.

✅ **Checkpoint:** you can SSH into the instance, and your S3 bucket contains `main/terraform.tfstate`.

Going straight on to Phase 5? Leave the instance running. Otherwise run `terraform destroy` now.

---

[← Phase 3](setup-phase-3.md) · [All phases](../../README.md#getting-started) · [Phase 5 →](setup-phase-5.md)
