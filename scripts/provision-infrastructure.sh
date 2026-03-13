#!/bin/bash
set -euo pipefail

# ==============================================================================
# Script: Provisionamento de Infraestrutura AWS (VPC + Bastion + RDS)
# Segurança: Zero Trust, Tags obrigatórias, Validações completas
# ==============================================================================

PROJECT_NAME="DataApp"
ENV="Prod"
AWS_REGION="us-east-1"
DB_USER="postgres"

# Nomenclatura padronizada
DB_IDENTIFIER="${PROJECT_NAME,,}-${ENV,,}-rds-privado"
BASE_TAGS="Key=Project,Value=$PROJECT_NAME Key=Environment,Value=$ENV"

# ==============================================================================
# VALIDAÇÕES PRÉ-EXECUÇÃO
# ==============================================================================
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI não encontrado. Instale: https://aws.amazon.com/cli/"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS inválidas ou não configuradas"
    exit 1
fi

# Solicitar senha do banco de forma segura
read -sp "🔐 Digite a senha do banco RDS (mínimo 8 caracteres): " DB_PASS
echo
if [ ${#DB_PASS} -lt 8 ]; then
    echo "❌ Senha muito curta"
    exit 1
fi

echo "🚀 Iniciando provisionamento: $PROJECT_NAME | $ENV | $AWS_REGION"

# ==============================================================================
# OBTER ZONAS DE DISPONIBILIDADE
# ==============================================================================
AZ1=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0].ZoneName' --output text --region "$AWS_REGION")
AZ2=$(aws ec2 describe-availability-zones --query 'AvailabilityZones[1].ZoneName' --output text --region "$AWS_REGION")

# ==============================================================================
# VPC E INTERNET GATEWAY
# ==============================================================================
echo "🌐 Criando VPC..."
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query 'Vpc.VpcId' --output text --region "$AWS_REGION")
aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames '{"Value":true}' --region "$AWS_REGION"
aws ec2 create-tags --resources "$VPC_ID" --tags Key=Name,Value="${PROJECT_NAME}-${ENV}-VPC" $BASE_TAGS --region "$AWS_REGION"

IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text --region "$AWS_REGION")
aws ec2 attach-internet-gateway --vpc-id "$VPC_ID" --internet-gateway-id "$IGW_ID" --region "$AWS_REGION"
aws ec2 create-tags --resources "$IGW_ID" --tags Key=Name,Value="${PROJECT_NAME}-${ENV}-IGW" $BASE_TAGS --region "$AWS_REGION"

# ==============================================================================
# SUBNETS
# ==============================================================================
echo "🏗️ Criando Subnets..."
SUBNET_PUB=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.1.0/24 --availability-zone "$AZ1" --query 'Subnet.SubnetId' --output text --region "$AWS_REGION")
aws ec2 create-tags --resources "$SUBNET_PUB" --tags Key=Name,Value="${PROJECT_NAME}-${ENV}-Subnet-Pub-${AZ1}" $BASE_TAGS --region "$AWS_REGION"

SUBNET_PRIV1=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.2.0/24 --availability-zone "$AZ1" --query 'Subnet.SubnetId' --output text --region "$AWS_REGION")
aws ec2 create-tags --resources "$SUBNET_PRIV1" --tags Key=Name,Value="${PROJECT_NAME}-${ENV}-Subnet-Priv-${AZ1}" $BASE_TAGS --region "$AWS_REGION"

SUBNET_PRIV2=$(aws ec2 create-subnet --vpc-id "$VPC_ID" --cidr-block 10.0.3.0/24 --availability-zone "$AZ2" --query 'Subnet.SubnetId' --output text --region "$AWS_REGION")
aws ec2 create-tags --resources "$SUBNET_PRIV2" --tags Key=Name,Value="${PROJECT_NAME}-${ENV}-Subnet-Priv-${AZ2}" $BASE_TAGS --region "$AWS_REGION"

# ==============================================================================
# ROTEAMENTO
# ==============================================================================
echo "🛣️ Configurando Roteamento..."
RT_PUB=$(aws ec2 create-route-table --vpc-id "$VPC_ID" --query 'RouteTable.RouteTableId' --output text --region "$AWS_REGION")
aws ec2 create-tags --resources "$RT_PUB" --tags Key=Name,Value="${PROJECT_NAME}-${ENV}-RouteTable-Pub" $BASE_TAGS --region "$AWS_REGION"
aws ec2 create-route --route-table-id "$RT_PUB" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" --region "$AWS_REGION"
aws ec2 associate-route-table --subnet-id "$SUBNET_PUB" --route-table-id "$RT_PUB" --region "$AWS_REGION"
aws ec2 modify-subnet-attribute --subnet-id "$SUBNET_PUB" --map-public-ip-on-launch --region "$AWS_REGION"

# ==============================================================================
# DB SUBNET GROUP
# ==============================================================================
DB_SUBNET_GROUP="${PROJECT_NAME,,}-${ENV,,}-db-subnet-group"
aws rds create-db-subnet-group \
    --db-subnet-group-name "$DB_SUBNET_GROUP" \
    --db-subnet-group-description "Subnets isoladas para $PROJECT_NAME" \
    --subnet-ids "$SUBNET_PRIV1" "$SUBNET_PRIV2" \
    --tags Key=Name,Value="$DB_SUBNET_GROUP" Key=Project,Value="$PROJECT_NAME" Key=Environment,Value="$ENV" \
    --region "$AWS_REGION"

# ==============================================================================
# SECURITY GROUPS
# ==============================================================================
echo "🛡️ Configurando Security Groups..."
BASTION_SG=$(aws ec2 create-security-group --group-name "${PROJECT_NAME}-${ENV}-Bastion-SG" --description "SG Bastion SSM" --vpc-id "$VPC_ID" --query 'GroupId' --output text --region "$AWS_REGION")
aws ec2 create-tags --resources "$BASTION_SG" --tags Key=Name,Value="${PROJECT_NAME}-${ENV}-Bastion-SG" $BASE_TAGS --region "$AWS_REGION"

DB_SG=$(aws ec2 create-security-group --group-name "${PROJECT_NAME}-${ENV}-RDS-SG" --description "SG RDS Privado" --vpc-id "$VPC_ID" --query 'GroupId' --output text --region "$AWS_REGION")
aws ec2 create-tags --resources "$DB_SG" --tags Key=Name,Value="${PROJECT_NAME}-${ENV}-RDS-SG" $BASE_TAGS --region "$AWS_REGION"

aws ec2 authorize-security-group-ingress --group-id "$DB_SG" --protocol tcp --port 5432 --source-group "$BASTION_SG" --region "$AWS_REGION"

# ==============================================================================
# IAM ROLE E INSTANCE PROFILE
# ==============================================================================
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

# ==============================================================================
# EC2 BASTION
# ==============================================================================
echo "🖥️ Provisionando Bastion..."
AMI_ID=$(aws ec2 describe-images --owners amazon --filters "Name=name,Values=al2023-ami-2023.*-x86_64" --query "sort_by(Images, &CreationDate)[-1].ImageId" --output text --region "$AWS_REGION")

aws ec2 run-instances \
    --image-id "$AMI_ID" --count 1 --instance-type t3.nano \
    --security-group-ids "$BASTION_SG" --subnet-id "$SUBNET_PUB" \
    --iam-instance-profile Name="$PROFILE_NAME" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${PROJECT_NAME}-${ENV}-Bastion},{Key=Project,Value=${PROJECT_NAME}},{Key=Environment,Value=${ENV}}]" \
    --region "$AWS_REGION"

# ==============================================================================
# RDS POSTGRESQL
# ==============================================================================
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
echo "✅ Infraestrutura provisionada com sucesso!"
echo "📋 Recursos criados:"
echo "   VPC: $VPC_ID"
echo "   Bastion SG: $BASTION_SG"
echo "   RDS SG: $DB_SG"
echo "   DB Identifier: $DB_IDENTIFIER"
echo ""
echo "⏳ O RDS levará ~5-10 minutos para ficar disponível"
