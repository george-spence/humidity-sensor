output "vpc_id" {
  description = "ID of the main VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID of the main subnet"
  value       = aws_subnet.main.id
}

output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.ec2.id
}
