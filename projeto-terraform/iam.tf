# ==============================================================================
# IAM Role para Bastion (SSM)
# ==============================================================================

resource "aws_iam_role" "bastion" {
  name = "${var.project_name}${var.environment}BastionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.project_name}${var.environment}BastionRole"
  }
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.project_name}${var.environment}BastionProfile"
  role = aws_iam_role.bastion.name

  tags = {
    Name = "${var.project_name}${var.environment}BastionProfile"
  }
}
