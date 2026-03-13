# ==============================================================================
# Configuração Centralizada do Projeto AWS
# ==============================================================================

# Identificação do Projeto
PROJECT_NAME="DataApp"
ENV="Prod"
AWS_REGION="us-east-1"

# Configuração de Portas
LOCAL_PORT="5433"
REMOTE_PORT="5432"

# Credenciais RDS
DB_USER="postgres"
# DB_PASS será solicitado interativamente no deploy

# ==============================================================================
# Nomenclatura Automática (NÃO ALTERAR)
# ==============================================================================
DB_IDENTIFIER="${PROJECT_NAME,,}-${ENV,,}-rds-privado"
BASTION_NAME="${PROJECT_NAME}-${ENV}-Bastion"
DB_SUBNET_GROUP="${PROJECT_NAME,,}-${ENV,,}-db-subnet-group"
ROLE_NAME="${PROJECT_NAME}${ENV}BastionRole"
PROFILE_NAME="${PROJECT_NAME}${ENV}BastionProfile"
BASE_TAGS="Key=Project,Value=$PROJECT_NAME Key=Environment,Value=$ENV"
