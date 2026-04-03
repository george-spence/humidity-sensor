output "cloudflare_ztna_sg_id" {
    description = "ID of security group with egress to Cloudflare ZTNA IPs"
    value       = aws_security_group.cloudflare_ztna_sg.id
}