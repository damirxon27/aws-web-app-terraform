output "vpc_id" {
  value = aws_vpc.main_vpc.id
}

output "load_balancer_dns" {
  value = aws_lb.web_lb.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.default.endpoint
}

