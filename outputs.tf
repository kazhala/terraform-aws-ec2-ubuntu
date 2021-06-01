output "vpc_id" {
  description = "The ID of the VPC."
  value       = var.vpc_id == null ? module.vpc[0].vpc_id : var.vpc_id
}

output "subnet_id" {
  description = "The ID of the subnet."
  value       = var.subnet_id == null ? module.vpc[0].public_subnets[0] : var.subnet_id
}

output "instance_id" {
  description = "The ID of the instance."
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "The ARN of the instance."
  value       = aws_instance.this.arn
}

output "sg_id" {
  description = "The ID of the security group."
  value       = aws_security_group.this.id
}

output "sg_arn" {
  description = "The ARN of the security group."
  value       = aws_security_group.this.arn
}

output "lambda_arns" {
  description = "The ARNs of the lambda functions."
  value = {
    start = aws_lambda_function.start.arn
    stop  = aws_lambda_function.stop.arn
  }
}
