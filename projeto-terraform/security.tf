# ==============================================================================
# Security Groups
# ==============================================================================

# Security Group do Bastion
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-${var.environment}-Bastion-SG"
  description = "SG Bastion SSM"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-Bastion-SG"
  }
}

# Security Group do RDS
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-RDS-SG"
  description = "SG RDS Privado"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-RDS-SG"
  }
}
