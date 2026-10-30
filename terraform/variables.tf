variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-1"
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t3.micro" # free-tier server
}

variable "my_ip" {
  description = "Your public IP for SSH access (CIDR format, e.g. 1.2.3.4/32)"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key contents for EC2 access"
  type        = string
}