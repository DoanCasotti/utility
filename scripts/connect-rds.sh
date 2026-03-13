#!/bin/bash
set -euo pipefail

# ==============================================================================
# Script: Conexão Segura ao RDS via Bastion (SSM Port Forwarding)
# Funcionalidades: Auto-start/stop, validações, cleanup automático
# ==============================================================================

PROJECT_NAME="DataApp"
ENV="Prod"
AWS_REGION="us-east-1"
LOCAL_PORT="5433"
REMOTE_PORT="5432"

DB_IDENTIFIER="${PROJECT_NAME,,}-${ENV,,}-rds-privado"
BASTION_NAME="${PROJECT_NAME}-${ENV}-Bastion"

# ==============================================================================
# VALIDAÇÕES PRÉ-EXECUÇÃO
# ==============================================================================
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI não encontrado"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS inválidas"
    exit 1
fi

if lsof -Pi :"$LOCAL_PORT" -sTCP:LISTEN -t &> /dev/null; then
    echo "❌ Porta local $LOCAL_PORT já está em uso"
    exit 1
fi

# ==============================================================================
# TRAP PARA CLEANUP AUTOMÁTICO
# ==============================================================================
cleanup() {
    if [ -n "${INSTANCE_ID:-}" ]; then
        echo ""
        echo "🛑 Encerrando conexão..."
        echo "⏳ Desligando Bastion..."
        aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" &> /dev/null || true
        echo "✅ Bastion desligado - custos zerados"
    fi
}
trap cleanup EXIT INT TERM

# ==============================================================================
# LOCALIZAR BASTION VIA TAGS
# ==============================================================================
echo "🔍 Buscando infraestrutura: $PROJECT_NAME | $ENV..."

INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=$PROJECT_NAME" \
              "Name=tag:Environment,Values=$ENV" \
              "Name=tag:Name,Values=$BASTION_NAME" \
              "Name=instance-state-name,Values=stopped,running" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text --region "$AWS_REGION")

if [ "$INSTANCE_ID" == "None" ] || [ -z "$INSTANCE_ID" ]; then
    echo "❌ Bastion não encontrado para $PROJECT_NAME ($ENV)"
    exit 1
fi
echo "✅ Bastion localizado: $INSTANCE_ID"

# ==============================================================================
# INICIAR BASTION SE NECESSÁRIO
# ==============================================================================
INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].State.Name" --output text --region "$AWS_REGION")

if [ "$INSTANCE_STATE" == "stopped" ]; then
    echo "⏳ Iniciando Bastion..."
    aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" &> /dev/null
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"
    echo "✅ Bastion iniciado"
fi

echo "⏳ Aguardando SSM Agent..."
MAX_WAIT=60
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$INSTANCE_ID" --query "InstanceInformationList[0].PingStatus" --output text --region "$AWS_REGION" 2>/dev/null | grep -q "Online"; then
        break
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "❌ SSM Agent não respondeu em ${MAX_WAIT}s"
    exit 1
fi
echo "✅ SSM Agent online"

# ==============================================================================
# OBTER ENDPOINT DO RDS
# ==============================================================================
DB_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --query "DBInstances[0].Endpoint.Address" \
    --output text --region "$AWS_REGION" 2>/dev/null)

if [ "$DB_ENDPOINT" == "None" ] || [ -z "$DB_ENDPOINT" ]; then
    echo "❌ RDS '$DB_IDENTIFIER' não encontrado ou indisponível"
    exit 1
fi
echo "✅ Endpoint RDS: $DB_ENDPOINT"

# ==============================================================================
# ESTABELECER TÚNEL SSM
# ==============================================================================
echo ""
echo "🔗 Túnel estabelecido!"
echo "📍 Conecte-se em: localhost:$LOCAL_PORT"
echo "⚠️  Pressione Ctrl+C para encerrar"
echo ""

aws ssm start-session \
    --target "$INSTANCE_ID" \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"$DB_ENDPOINT\"],\"portNumber\":[\"$REMOTE_PORT\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}" \
    --region "$AWS_REGION"
