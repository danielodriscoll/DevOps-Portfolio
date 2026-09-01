# Look up the latest Amazon Linux 2023 AMI (the OS image for your server)
# Rather than hardcode an AMI ID (which changes per region and over time), we query for the newest one
data "aws_ami" "amazon_linux" {
  most_recent = true       # get the newest matching image
  owners      = ["amazon"] # only official Amazon-owned images (trusted)

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"] # Amazon Linux 2023, 64-bit
  }
}

# Create an SSH key pair so you can log into the instance
# This uploads your LOCAL public key to AWS; you keep the private key to authenticate
resource "aws_key_pair" "deployer" {
  key_name   = "devops-portfolio-key" # name AWS stores it under
  public_key = var.ssh_public_key     # reads your  public key var
}

# Security group = firewall rules for your instance
resource "aws_security_group" "web" {
  name        = "devops-portfolio-sg"
  description = "Allow SSH from my IP and HTTP from anywhere"

  # Inbound rule: SSH (port 22) — ONLY from your IP
  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip] # your IP from terraform.tfvars — locks SSH to just you
  }

  # Inbound rule: HTTP (port 80) — locked to my IP during testing
  ingress {
    description = "HTTP from my IP (testing only)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.my_ip] # only I can reach the app while testing
  }

  # Outbound rule: allow all outgoing traffic (so the server can download updates, pull images, etc.)
  # tfsec:ignore:aws-ec2-no-public-egress-sgr
  egress {
    description = "Allow all outbound for OS updates, image pulls, and AWS API access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 = all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "devops-portfolio-sg"
  }
}

# The EC2 instance itself — your actual cloud server
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.deployer.key_name
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name   # NEW LINE — attaches the role

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name    = "devops-portfolio"
    Project = "devops-portfolio"
  }
}

# IAM role: the "identity" the EC2 assumes when it runs
  resource "aws_iam_role" "ec2_role" {
    name = "devops-portfolio-ec2-role"

    # Trust policy: which AWS service is allowed to assume this role
    # In this case, only the EC2 service can, meaning only an EC2 instance can act as this role
    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }]
    })

    tags = {
      Project = "devops-portfolio"
    }
  }

# IAM policy: what this role is *allowed to do*
# Least privilege: only read the one specific secret, nothing else in AWS
resource "aws_iam_role_policy" "read_ghcr_secret" {
name = "read-ghcr-secret"
role = aws_iam_role.ec2_role.id

policy = jsonencode({
  Version = "2012-10-17"
  Statement = [{
    Effect = "Allow"
    Action = [
      "secretsmanager:GetSecretValue"    # read a secret's value
    ]
    Resource = aws_secretsmanager_secret.ghcr_token.arn   # ONLY this specific secret
  }]
})
}

# Instance profile: the "carrier" that attaches an IAM role to an EC2 instance
# EC2 needs this wrapper — you can't attach an IAM role directly, you attach the profile
resource "aws_iam_instance_profile" "ec2_profile" {
name = "devops-portfolio-ec2-profile"
role = aws_iam_role.ec2_role.name
}

# The secret container itself — just an empty "slot" with a name
# The actual token value is put in separately via AWS CLI (never in Terraform)
resource "aws_secretsmanager_secret" "ghcr_token" {
  name        = "devops-portfolio/ghcr-token"    # / creates a namespace-style path
  description = "GitHub Container Registry pull token for the EC2 to authenticate with ghcr.io"

  # Free-tier friendly: no automatic rotation, no KMS custom key
  recovery_window_in_days = 0    # delete immediately on destroy (default is 30-day recovery window)
                                  # Set to 0 for a learning project so terraform destroy actually deletes
                                  # In production you'd leave this longer to protect against accidents

  tags = {
    Project = "devops-portfolio"
  }
}