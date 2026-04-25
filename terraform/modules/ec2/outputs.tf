output "main_instance_id" {
  description = "ID of the main EC2 instance"
  value       = aws_instance.main.id
}
