locals {
  lambda = {
    start = {
      file = "${path.module}/lambda/start.py"
      zip  = "${path.module}/lambda/start.zip"
    }

    stop = {
      file = "${path.module}/lambda/stop.py"
      zip  = "${path.module}/lambda/stop.zip"
    }
  }

  event = {
    start = {
      AEDT = "cron(0 20 ? * SUN-THU *)"
      AEST = "cron(0 21 ? * SUN-THU *)"
    }

    stop = {
      AEDT = "cron(0 8 ? * * *)"
      AEST = "cron(0 9 ? * * *)"
    }
  }
}

resource "aws_security_group" "this" {
  name_prefix = var.name
  vpc_id      = var.vpc_id
  description = "${var.name} security group."

  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "inbound_ssh" {
  description       = "Inbound ssh."
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.this.id
  cidr_blocks       = [for ip in var.ip_addresses : "${ip}/32"]
}

resource "aws_security_group_rule" "inbound_self" {
  description       = "Inbound ssh."
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.this.id
  self              = true
}

resource "aws_security_group_rule" "outbound_all" {
  description       = "Outbound all."
  type              = "egress"
  to_port           = 0
  protocol          = "-1"
  from_port         = 0
  security_group_id = aws_security_group.this.id
  cidr_blocks       = ["0.0.0.0/0"] # tfsec:ignore:AWS007
}

resource "aws_sns_topic" "this" {
  count = var.email != null ? 1 : 0

  # checkov:skip=CKV_AWS_26:No encryption.
  name_prefix = var.name

  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_sns_topic_subscription" "this" {
  count = var.email != null ? 1 : 0

  topic_arn = aws_sns_topic.this[0].arn
  protocol  = "email"
  endpoint  = var.email
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_permission" {
  statement {
    actions = [
      "ec2:StartInstances",
      "ec2:StopInstances",
    ]

    resources = [aws_instance.this.arn]
  }

  statement {
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = aws_sns_topic.this

    content {
      actions = ["sns:Publish"]

      resources = [aws_sns_topic.this[statement.key].arn]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name_prefix        = "lambda-${var.name}-"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "ec2-sns-start-stop"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_permission.json
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "random_id" "lambda" {
  byte_length = 8
}

data "archive_file" "lambda_start" {
  type             = "zip"
  source_file      = local.lambda.start.file
  output_path      = local.lambda.start.zip
  output_file_mode = "0666"
}

# tfsec:ignore:aws-lambda-enable-tracing
resource "aws_lambda_function" "start" {
  # checkov:skip=CKV_AWS_116:No dlq.
  # checkov:skip=CKV_AWS_117:No vpc.
  # checkov:skip=CKV_AWS_50:No x-ray.
  # checkov:skip=CKV_AWS_115:No limit.
  function_name    = "${var.name}-start-${random_id.lambda.hex}"
  filename         = local.lambda.start.zip
  source_code_hash = data.archive_file.lambda_start.output_base64sha256
  handler          = "start.lambda_handler"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.8"
  timeout          = 60

  environment {
    variables = {
      "INSTANCE"  = aws_instance.this.id
      "TOPIC_ARN" = var.email != null ? aws_sns_topic.this[0].arn : ""
    }
  }

  tags = var.tags
}

data "archive_file" "lambda_stop" {
  type             = "zip"
  source_file      = local.lambda.stop.file
  output_path      = local.lambda.stop.zip
  output_file_mode = "0666"
}

# tfsec:ignore:aws-lambda-enable-tracing
resource "aws_lambda_function" "stop" {
  # checkov:skip=CKV_AWS_116:No dlq.
  # checkov:skip=CKV_AWS_117:No vpc.
  # checkov:skip=CKV_AWS_50:No x-ray.
  # checkov:skip=CKV_AWS_115:No limit.
  function_name    = "${var.name}-stop-${random_id.lambda.hex}"
  filename         = local.lambda.stop.zip
  source_code_hash = data.archive_file.lambda_stop.output_base64sha256
  handler          = "stop.lambda_handler"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.8"
  timeout          = 10

  environment {
    variables = {
      "INSTANCE" = aws_instance.this.id
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "lambda_start" {
  name_prefix         = "lambda-${var.name}-start-"
  schedule_expression = var.start_schedule == null ? local.event.start[var.time_zone] : var.start_schedule
  is_enabled          = var.enable_auto_start

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_event_target" "lambda_start" {
  rule      = aws_cloudwatch_event_rule.lambda_start.name
  arn       = aws_lambda_function.start.arn
  target_id = aws_lambda_function.start.id
}

resource "aws_lambda_permission" "lambda_start" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_start.arn
}

resource "aws_cloudwatch_event_rule" "lambda_stop" {
  name_prefix         = "lambda-${var.name}-stop-"
  schedule_expression = var.stop_schedule == null ? local.event.stop[var.time_zone] : var.stop_schedule
  is_enabled          = var.enable_auto_stop

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_event_target" "lambda_stop" {
  rule      = aws_cloudwatch_event_rule.lambda_stop.name
  arn       = aws_lambda_function.stop.arn
  target_id = aws_lambda_function.stop.id
}

resource "aws_lambda_permission" "lambda_stop" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_stop.arn
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name_prefix        = "ec2-${var.name}-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ec2" {
  count = length(var.instance_permission_policies)

  role       = aws_iam_role.ec2.name
  policy_arn = var.instance_permission_policies[count.index]
}

resource "aws_iam_instance_profile" "this" {
  name_prefix = "${var.name}-"
  role        = aws_iam_role.ec2.name

  tags = var.tags
}

data "aws_ssm_parameter" "ami" {
  name = "/aws/service/canonical/ubuntu/server/20.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

resource "aws_instance" "this" {
  # checkov:skip=CKV2_AWS_17:Already configured.
  # checkov:skip=CKV_AWS_126:No detailed monitoring.
  iam_instance_profile   = aws_iam_instance_profile.this.name
  ami                    = var.ami == null ? data.aws_ssm_parameter.ami.value : var.ami
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.this.id]
  subnet_id              = var.subnet_id
  ebs_optimized          = true

  root_block_device {
    encrypted             = true
    delete_on_termination = true
    volume_type           = "gp3"
    volume_size           = var.volume_size
  }

  user_data = <<EOF
#!/bin/bash -ex
sudo sed -i 's/^.*PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
sudo sed -i 's/^.*PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sudo service ssh restart
echo ubuntu:${var.instance_password} | sudo chpasswd
EOF

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(
    {
      Name = var.name
    },
    var.tags
  )
}
