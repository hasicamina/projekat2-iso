output "alb_dns_name" {
  description = "DNS Load Balancer-a"
  value       = aws_lb.main.dns_name
}

output "rds_endpoint" {
  description = "RDS PostgreSQL konekcioni string"
  value       = aws_db_instance.postgres.endpoint
}

output "app_instance_ips" {
  description = "Javne IP adrese EC2 instanci"
  value       = aws_instance.app[*].public_ip
}