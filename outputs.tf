output "aws_instance" {
  description = "Outputs of the EC2 instance."

  value = {
    this = aws_instance.this
  }
}

output "aws_security_group" {
  description = "Security group deployed for the instance."

  value = {
    this = aws_security_group.this
  }
}

output "aws_lambda_function" {
  description = "Lambda automation deployed."

  value = {
    start = aws_lambda_function.start
    stop  = aws_lambda_function.stop
  }
}

output "aws_iam_role" {
  description = "IAM roles deployed."

  value = {
    lambda = aws_iam_role.lambda
    ec2    = aws_iam_role.ec2
  }
}
