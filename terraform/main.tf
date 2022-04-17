data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  name               = "${local.prefix}-vpc"
  cidr               = "10.0.0.0/16"
  azs                = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_nat_gateway = false
  enable_vpn_gateway = false
}

resource "aws_iam_policy" "githubactions_runner" {
  name = "${local.prefix}-githubactions-runner-policy"
  policy = jsonencode(
    {
      Statement = [
        {
          Action = [
            "ssm:GetParameters",
            "kms:Decrypt",
          ]
          Effect = "Allow"
          Resource = [
            "arn:aws:ssm:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:parameter/GITHUB_ACTIONS_RUNNER_TOKEN",
            "arn:aws:kms:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:key:alias/aws/ssm",
          ]
        },
      ]
      Version = "2012-10-17"
    }
  )
}


resource "aws_iam_role" "githubactions_runner" {
  name                 = "${local.prefix}-githubactions-runner-role"
  max_session_duration = 3600
  path                 = "/"
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "ec2.amazonaws.com"
          }
        },
      ]
      Version = "2012-10-17"
    }
  )
  force_detach_policies = false
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    aws_iam_policy.githubactions_runner.arn,
  ]
}

resource "aws_iam_instance_profile" "githubactions_runner" {
  name = "${local.prefix}-githubactions-runner-role"
  role = aws_iam_role.githubactions_runner.name
}

resource "aws_security_group" "githubactions_runner" {
  description = "for githubactions runner"
  egress = [
    {
      cidr_blocks = [
        "0.0.0.0/0",
      ]
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      description      = ""
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    },
  ]
  name = "${local.prefix}-githubactions-runner-sg"
  tags = {
    "Name" = "${local.prefix}-githubactions-runner-sg"
  }
  vpc_id = module.vpc.vpc_id
}

resource "aws_launch_template" "githubactions_runner" {
  depends_on = [aws_security_group.githubactions_runner]
  name = join("-",
    [
      local.prefix,
      "githubactions",
      "runner",
      "launch",
      "template",
    ]
  )
  image_id      = local.image_id
  instance_type = local.instance_type
  iam_instance_profile {
    name = aws_iam_instance_profile.githubactions_runner.name
  }
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.githubactions_runner.id]
  }
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 20
    }
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.prefix}-githubactions-runner"
    }
  }
  user_data = base64encode(templatefile("${path.module}/template/userdata.sh", {
    owner      = var.owner
    repository = var.repository
    label      = local.label
  }))
}

resource "aws_autoscaling_group" "githubactions_runner" {
  name                      = "${local.prefix}-githubactions-autoscaling-group"
  desired_capacity          = local.desired_capacity
  max_size                  = local.max_size
  min_size                  = local.min_size
  default_cooldown          = 0
  health_check_grace_period = 60
  vpc_zone_identifier       = module.vpc.public_subnets
  launch_template {
    id      = aws_launch_template.githubactions_runner.id
    version = "$Latest"
  }
}
