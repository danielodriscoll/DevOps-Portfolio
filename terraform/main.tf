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
  key_name   = "devops-portfolio-key"        # name AWS stores it under
  public_key = file("~/.ssh/id_ed25519.pub") # reads your local public key file
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
  egress {
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
  ami                    = data.aws_ami.amazon_linux.id   # the AMI we looked up above
  instance_type          = var.instance_type              # t3.micro, from variables.tf
  key_name               = aws_key_pair.deployer.key_name # attach the SSH key
  vpc_security_group_ids = [aws_security_group.web.id]    # attach the firewall rules

  tags = {
    Name    = "devops-portfolio" # shows in the EC2 console
    Project = "devops-portfolio"
  }
}