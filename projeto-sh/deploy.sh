#!/bin/bash
set -euo pipefail

# ==============================================================================
# Script: Deploy Completo - Provisiona TODA a infraestrutura
# ==============================================================================

# Carregar variáveis do .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
elif [ -f "$SCRIPT_DIR/../.env" ]; then
    set -a
    source "$SCRIPT_DIR/../.env"
    set +a
else
    echo "❌ Arquivo .env não encontrado. Copie .env.example para .env"
    exit 1
fi

# Configurar AWS Profile se especificado
if [ -n "${AWS_PROFILE:-}" ] && [ "$AWS_PROFILE" != "default" ]; then
    export AWS_PROFILE
    echo "🔑 Usando AWS Profile: $AWS_PROFILE"
fi

# Variáveis derivadas
DB_IDENTIFIER="${PROJECT_NAME,,}-${ENV,,}-rds-privado"
BASE_TAGS="Key=Project,Value=$PROJECT_NAME Key=Environment,Value=$ENV"

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI não encontrado"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS inválidas"
    exit 1
fi

# Mostrar conta AWS em uso
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_USER=$(aws sts get-caller-identity --query Arn --output text | cut -d'/' -f2)
echo "📋 Conta AWS: $AWS_ACCOUNT"
echo "👤 Usuário: $AWS_USER"
echo ""

read -sp "🔐 Digite a senha do banco RDS (mínimo 8 caracteres): " DB_PASS
echo
if [ ${#DB_PASS} -lt 8 ]; then
    echo "❌ Senha muito curta (mínimo 8 caracteres)"
    exit 1
fi

# Validar senha AWS RDS (sem caracteres especiais problemáticos)
if [[ "$DB_PASS" =~ [@/\"\'] ]]; then
    echo "❌ Senha não pode conter: @ / \" '"
    exit 1
fi

echo "🚀 Iniciando deploy completo: $PROJECT_NAME | $ENV"

# Verificar se infraestrutura já existe
VPC_EXISTS=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${PROJECT_NAME}-${ENV}-VPC" --query "Vpcs[0].VpcId" --output text --region "$AWS_REGION" 2>/dev/null || echo "None")
if [ "$VPC_EXISTS" != "None" ] && [ -n "$VPC_EXISTS" ]; then
    echo "⚠️  Infraestrutura já existe para $PROJECT_NAME ($ENV)"
    read -p "Deseja continuar mesmo assim? (s/N): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Ss]$ ]]; then
        echo "❌ Deploy cancelado"
        exit 0
    fi
fi

DB_IDENTIFIER="${PROJECT_NAME,,}-${ENV,,}-rds-privado"
BASE_TAGS="Key=Project,Value=$PROJECT_NAME Key=Environment,Value=$ENV"

AZ1=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].ZoneName' --output text --region "$AWS_REGION")
AZ2=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[1].ZoneName' --output text --region "$AWS_REGION")

echo "🌐 Criando VPC..."
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' --output text --region "$AWS_REGION")
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}' --region "$AWS_REGION"
aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value="${PROJECT_NAME}-${ENV}-VPC" $BASE_TAGS --region "$AWS_REGION"

IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text --region "$AWS_REGION")
aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID" --region "$AWS_REGION"
aws ec2 create-tags --resources "$IGW_ID" --tags Key=Name,Value="${PROJECT_NAME}-${ENV}-IGW" $BASE_TAGS --region "$AWS_REGION"

echo "🏗️ Criando Subnets..."
SUBNET_PUB=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.1.0/24 --availability-zone "$AZ1" --query 'Subnet.SubnetId' --output text --region "$AWS_REGION")
aws ec2 create-tags --resources "$SUBNET_PUB" --tags Key=Name,Value="${PROJECT_NAME}-${ENV}-Subnet-Pub-${AZ1}" $BASE_TAGS --region "$AWS_REGION"

SUBNET_PRIV1=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.2.0/24 --availability-zone "$AZ1" --query 'Subnet.SubnetId' --output text --region "$AWS_REGION")
aws ec2 create-tags --resources "$SUBNET_PRIV1" --tags Key=Name,Value="${PROJECT_NAME}-${ENV}-Subnet-Priv-${AZ1}" $BASE_TAGS --region "$AWS_REGION"

SUBNET_PRIV2=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.3.0/24 --availability-zone "$AZ2" --query 'Subnet.SubnetId' --output text --region "$AWS_REGION")
aws ec2 create-tags --resources "$SUBNET_PRIV2" --tags Key=Name,Value="${PROJECT_NAME}-${ENV}-Subnet-Priv-${AZ2}" $BASE_TAGS --region "$AWS_REGION"

echo "🛣️ Configurando Roteamento..."
RT_PUB=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query 'RouteTable.RouteTableId' --output text --region "$AWS_REGION")
aws ec2 create-tags --resources "$RT_PUB" --tags Key=Name,Value="${PROJECT_NAME}-${ENV}-RouteTable-Pub" $BASE_TAGS --region "$AWS_REGION"
aws ec2 create-route --route-table-id "$RT_PUB" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" --region "$AWS_REGION"
aws ec2 associate-route-table --subnet-id "$SUBNET_PUB" --route-table-id "$RT_PUB" --region "$AWS_REGION"
aws ec2 modify-subnet-attribute --subnet-id "$SUBNET_PUB" --map-public-ip-on-launch --region "$AWS_REGION"

DB_SUBNET_GROUP="${PROJECT_NAME,,}-${ENV,,}-db-subnet-group"
aws rds create-db-subnet-group \
    --db-subnet-group-name "$DB_SUBNET_GROUP" \
    --db-subnet-group-description "Subnets isoladas para $PROJECT_NAME" \
    --subnet-ids "$SUBNET_PRIV1" "$SUBNET_PRIV2" \
    --tags Key=Name,Value="$DB_SUBNET_GROUP" Key=Project,Value="$PROJECT_NAME" Key=Environment,Value="$ENV" \
    --region "$AWS_REGION"

echo "🛡️ Configurando Security Groups..."
BASTION_SG=$(aws ec2 create-security-group --group-name "${PROJECT_NAME}-${ENV}-Bastion-SG" --description "SG Bastion SSM" --vpc-id "$VPC_ID" --query 'GroupId' --output text --region "$AWS_REGION")
aws ec2 create-tags --resources "$BASTION_SG" --tags Key=Name,Value="${PROJECT_NAME}-${ENV}-Bastion-SG" $BASE_TAGS --region "$AWS_REGION"

DB_SG=$(aws ec2 create-security-group --group-name "${PROJECT_NAME}-${ENV}-RDS-SG" --description "SG RDS Privado" --vpc-id "$VPC_ID" --query 'GroupId' --output text --region "$AWS_REGION")
aws ec2 create-tags --resources "$DB_SG" --tags Key=Name,Value="${PROJECT_NAME}-${ENV}-RDS-SG" $BASE_TAGS --region "$AWS_REGION"

aws ec2 authorize-security-group-ingress --group-id "$DB_SG" --protocol tcp --port 5432 --source-group "$BASTION_SG" --region "$AWS_REGION"

echo "🔑 Configurando IAM..."
ROLE_NAME="${PROJECT_NAME}${ENV}BastionRole"
PROFILE_NAME="${PROJECT_NAME}${ENV}BastionProfile"

if ! aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
    aws iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
    aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
fi

if ! aws iam get-instance-profile --instance-profile-name "$PROFILE_NAME" &> /dev/null; then
    aws iam create-instance-profile --instance-profile-name "$PROFILE_NAME"
    sleep 2
    aws iam add-role-to-instance-profile --instance-profile-name "$PROFILE_NAME" --role-name "$ROLE_NAME"
fi

echo "⏳ Aguardando propagação IAM (15s)..."
sleep 15

echo "🖥️ Provisionando Bastion..."
AMI_ID=$(aws ec2 describe-images --owners amazon --filters "Name=name,Values=al2023-ami-2023.*-x86_64" --query "sort_by(Images, &CreationDate)[-1].ImageId" --output text --region "$AWS_REGION")

aws ec2 run-instances \
    --image-id "$AMI_ID" --count 1 --instance-type t3.nano \
    --security-group-ids "$BASTION_SG" --subnet-id "$SUBNET_PUB" \
    --iam-instance-profile Name="$PROFILE_NAME" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PROJECT_NAME}-${ENV}-Bastion},{Key=Project,Value=${PROJECT_NAME}},{Key=Environment,Value=${ENV}}]" \
    --region "$AWS_REGION"

echo "🗄️ Provisionando RDS..."
aws rds create-db-instance \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --db-instance-class db.t4g.micro --engine postgres \
    --master-username "$DB_USER" --master-user-password "$DB_PASS" \
    --allocated-storage 20 --storage-type gp3 \
    --db-subnet-group-name "$DB_SUBNET_GROUP" \
    --no-publicly-accessible --vpc-security-group-ids "$DB_SG" \
    --no-multi-az --backup-retention-period 7 \
    --tags Key=Name,Value="${PROJECT_NAME}-${ENV}-RDS" Key=Project,Value="$PROJECT_NAME" Key=Environment,Value="$ENV" \
    --region "$AWS_REGION"

echo ""
echo "✅ Deploy completo finalizado!"
echo ""
echo "💰 Estimativa de Custos (us-east-1):"
echo "   • Bastion (t3.nano): ~$3.80/mês (24/7)"
echo "   • RDS (db.t4g.micro): ~$12.41/mês (24/7)"
echo "   • Storage (20GB gp3): ~$1.60/mês"
echo "   • TOTAL: ~$17.81/mês (24/7 ligado)"
echo ""
echo "💡 Dicas de economia:"
echo "   • Desligue quando não usar: scripts/stop-rds.sh + scripts/stop-bastion.sh (~50% economia)"
echo "   • Delete com snapshot: scripts/hibernate-rds.sh (~85% economia)"
echo ""
echo "⏳ RDS levará ~5-10 minutos para ficar disponível"
echo "🔗 Use './connect.sh' para conectar ao banco"
