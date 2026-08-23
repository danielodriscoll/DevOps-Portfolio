variable "region" {
  description = "AWS region for all resources"   # human-readable note
  type        = string                           # must be text
  default     = "eu-west-1"                       # used if not overridden
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t3.micro"                        # free-tier-eligible / cheap; DON'T change to anything bigger
}

variable "my_ip" {
  description = "Your public IP for SSH access (CIDR format, e.g. 1.2.3.4/32)"
  type        = string
  # no default — you'll pass this in, since your IP is specific to you and shouldn't be committed
}