output "vpc_id" {
  description = "ID of the main VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "bootstrap_sg_id" {
  description = "ID of the bootstrap security group (broad egress for cloud-init only)"
  value       = aws_security_group.bootstrap.id
}
