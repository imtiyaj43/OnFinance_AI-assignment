output "cluster_id" {
  value = aws_eks_cluster.terraform.id
}

output "node_group_id" {
  value = aws_eks_node_group.terraform.id
}

output "vpc_id" {
  value = aws_vpc.terraform_vpc.id
}

output "public_subnet_ids" {
  value = aws_subnet.public_subnet[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private_subnet[*].id
}

output "mysql_endpoint" {
  value = aws_db_instance.mysql.endpoint
}

output "ecr_repository_url" {
  value = aws_ecr_repository.onfinance_backend.repository_url
}
