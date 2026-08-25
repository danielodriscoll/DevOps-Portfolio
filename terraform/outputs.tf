output "instance_public_ip" {
  value       = aws_instance.web.public_ip # the server's public IP address
  description = "Public IP of the EC2 instance — use this to SSH in"
}