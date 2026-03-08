# --- IAM Permissions/ Roles ---
resource "aws_iam_role" "ec2" {
  name = "ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = ["ec2.amazonaws.com"]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

data "aws_kms_key" "ssm_default" {
  key_id = "alias/aws/ssm"
}

resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2-policy"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = var.secret_arns
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt"
        ],
        Resource = data.aws_kms_key.ssm_default.arn
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject"
        ],
        Resource = "${var.s3_config_bucket_arn}/*",
      },
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
        ],
        Resource = "${var.s3_config_bucket_arn}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "ec2"
  role = aws_iam_role.ec2.name
}


# --- EC2 ---
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

resource "aws_instance" "main" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  iam_instance_profile = aws_iam_instance_profile.ec2.name

  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.vpc_security_group_ids

  ebs_optimized = true
  monitoring    = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data_base64 = base64encode(templatefile("${path.module}/src/user-data.sh", {
    REGION = var.aws_region
    S3_CONFIG_BUCKET_NAME = var.s3_config_bucket_name
  }))

  # Ensure these are created before the cloud init runs to avoid conflicts
  depends_on = [
    aws_cloudwatch_log_group.user_data,
  ]

  tags = {
    Name = "${var.project_name}-main"
  }
}

resource "aws_ebs_volume" "main" {
  availability_zone = aws_instance.main.availability_zone
  size              = 20
  type              = "gp3"
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.main.id
  instance_id = aws_instance.main.id
}

resource "aws_cloudwatch_log_group" "user_data" {
  name              = "/ec2/user-data"
  retention_in_days = 30
}