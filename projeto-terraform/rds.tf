# ==============================================================================
# RDS PostgreSQL
# ==============================================================================

resource "aws_db_instance" "main" {
  identifier = "${lower(var.project_name)}-${lower(var.environment)}-rds-privado"

  engine         = "postgres"
  engine_version = "16.1"
  instance_class = var.rds_instance_class

  allocated_storage = var.rds_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "postgres"
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az               = false
  backup_retention_period = 7
  skip_final_snapshot    = true
  deletion_protection    = false

  tags = {
    Name = "${var.project_name}-${var.environment}-RDS"
  }
}
