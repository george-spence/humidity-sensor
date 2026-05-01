# --- IAM Role & Permissions ---

resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = ["ec2.amazonaws.com"] }
      Action    = "sts:AssumeRole"
    }]
  })
}

data "aws_kms_key" "ssm_default" {
  key_id = "alias/aws/ssm"
}

resource "aws_iam_role_policy" "ec2_policy" {
  name = "${var.project_name}-ec2-policy"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = var.secret_arns
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = data.aws_kms_key.ssm_default.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${var.s3_config_bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = var.s3_config_bucket_arn
      },
      {
        # Allows user-data to swap from the bootstrap SG to the Cloudflare ZTNA SG.
        Effect   = "Allow"
        Action   = ["ec2:ModifyInstanceAttribute"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2"
  role = aws_iam_role.ec2.name
}


# --- AMI ---

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}


# --- Launch Template ---

resource "aws_launch_template" "main" {
  name_prefix   = "${var.project_name}-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = var.vpc_security_group_ids
  }

  ebs_optimized = true

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/sdf"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/src/user-data.sh", {
    REGION                 = var.aws_region
    S3_CONFIG_BUCKET_NAME  = var.s3_config_bucket_name
    PROJECT_NAME           = var.project_name
    ENVIRONMENT            = var.environment
    CLOUDFLARE_ZTNA_SG_ID  = var.cloudflare_ztna_sg_id
  }))

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${var.project_name}-main" }
  }

  tag_specifications {
    resource_type = "volume"
    tags = { Name = "${var.project_name}-data" }
  }

  depends_on = [aws_cloudwatch_log_group.user_data]

  lifecycle {
    create_before_destroy = true
  }
}


# --- Auto Scaling Group ---

resource "aws_autoscaling_group" "main" {
  name                      = "${var.project_name}-asg"
  vpc_zone_identifier       = [var.subnet_id]
  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-main"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}


# --- CloudWatch ---

resource "aws_cloudwatch_log_group" "user_data" {
  name              = "/ec2/user-data"
  retention_in_days = 30
}
