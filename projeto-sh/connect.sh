#!/bin/bash
set -euo pipefail

# ==============================================================================
# Script: Conectar ao RDS - Liga Bastion, Abre Túnel, Desliga Bastion
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
fi

# Variáveis derivadas
DB_IDENTIFIER="${PROJECT_NAME,,}-${ENV,,}-rds-privado"
BASTION_NAME="${PROJECT_NAME}-${ENV}-Bastion"

if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ Credenciais AWS inválidas"
    exit 1
fi

if lsof -Pi :"$LOCAL_PORT" -sTCP:LISTEN -t &> /dev/null; then
    echo "❌ Porta $LOCAL_PORT já está em uso"
    exit 1
fi

cleanup() {
    if [ -n "${INSTANCE_ID:-}" ]; then
        echo ""
        echo "🛑 Túnel encerrado"
        echo "⏳ Desligando Bastion em 10 segundos..."
        echo "   (Pressione Ctrl+C novamente para cancelar)"
        sleep 10 2>/dev/null || { echo "❌ Cancelado - Bastion continua ligado"; exit 0; }
        aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" &> /dev/null || true
        echo "✅ Bastion desligado - custos zerados"
    fi
}
trap cleanup EXIT INT TERM

echo "🔍 Localizando Bastion..."
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=$PROJECT_NAME" \
              "Name=tag:Environment,Values=$ENV" \
              "Name=tag:Name,Values=$BASTION_NAME" \
              "Name=instance-state-name,Values=stopped,running" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text --region "$AWS_REGION")

if [ "$INSTANCE_ID" == "None" ] || [ -z "$INSTANCE_ID" ]; then
    echo "❌ Bastion não encontrado"
    exit 1
fi

INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].State.Name" --output text --region "$AWS_REGION")

if [ "$INSTANCE_STATE" == "stopped" ]; then
    echo "⏳ Iniciando Bastion..."
    aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" &> /dev/null
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"
fi

echo "⏳ Aguardando SSM Agent..."
for i in {1..12}; do
    if aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$INSTANCE_ID" --query "InstanceInformationList[0].PingStatus" --output text --region "$AWS_REGION" 2>/dev/null | grep -q "Online"; then
        break
    fi
    [ $i -eq 12 ] && { echo "❌ SSM timeout"; exit 1; }
    sleep 5
done

echo "🔍 Obtendo endpoint RDS..."
DB_INFO=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_IDENTIFIER" \
    --query "DBInstances[0].[Endpoint.Address,DBInstanceStatus]" \
    --output text --region "$AWS_REGION" 2>/dev/null || echo "None None")

DB_ENDPOINT=$(echo "$DB_INFO" | awk '{print $1}')
DB_STATUS=$(echo "$DB_INFO" | awk '{print $2}')

if [ "$DB_ENDPOINT" == "None" ] || [ -z "$DB_ENDPOINT" ]; then
    echo "❌ RDS não encontrado"
    exit 1
fi

if [ "$DB_STATUS" != "available" ]; then
    echo "⚠️  RDS está em estado: $DB_STATUS"
    if [ "$DB_STATUS" == "stopped" ]; then
        echo "💡 Execute: scripts/start-rds.sh"
    fi
    exit 1
fi

echo ""
echo "🔗 Túnel ativo em localhost:$LOCAL_PORT"
echo "⚠️  Pressione Ctrl+C para encerrar"
echo "ℹ️  Bastion será desligado automaticamente 10s após fechar o túnel"
echo ""

aws ssm start-session \
    --target "$INSTANCE_ID" \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "{\"host\":[\"$DB_ENDPOINT\"],\"portNumber\":[\"$REMOTE_PORT\"],\"localPortNumber\":[\"$LOCAL_PORT\"]}" \
    --region "$AWS_REGION"
