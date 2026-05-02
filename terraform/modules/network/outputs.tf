output "vpc_id" {
  description = "ID of the main VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "bootstrap_sg_id" {
  description = "ID of the EC2 security group (no inbound; outbound for Tailscale, SSM, Docker, S3, DNS, NTP)"
  value       = aws_security_group.bootstrap.id
}
