#!/bin/bash
set -euo pipefail

# ==============================================================================
# Script: Estimativa de Custos AWS (us-east-1)
# ==============================================================================

# Carregar variáveis do .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../.env" ]; then
    set -a
    source "$SCRIPT_DIR/../.env"
    set +a
else
    echo "❌ Arquivo .env não encontrado"
    exit 1
fi

if [ -n "${AWS_PROFILE:-}" ] && [ "$AWS_PROFILE" != "default" ]; then
    export AWS_PROFILE
fi

DB_IDENTIFIER="${PROJECT_NAME,,}-${ENV,,}-rds-privado"
BASTION_NAME="${PROJECT_NAME}-${ENV}-Bastion"

echo "💰 Estimativa de Custos - Região: $AWS_REGION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verificar recursos existentes
BASTION_STATE="não existe"
RDS_STATE="não existe"
SNAPSHOT_COUNT=0

if aws ec2 describe-instances --filters "Name=tag:Name,Values=$BASTION_NAME" "Name=instance-state-name,Values=running,stopped" --query "Reservations[0].Instances[0].State.Name" --output text --region "$AWS_REGION" 2>/dev/null | grep -q "running\|stopped"; then
    BASTION_STATE=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$BASTION_NAME" --query "Reservations[0].Instances[0].State.Name" --output text --region "$AWS_REGION" 2>/dev/null)
fi

if aws rds describe-db-instances --db-instance-identifier "$DB_IDENTIFIER" --region "$AWS_REGION" &> /dev/null; then
    RDS_STATE=$(aws rds describe-db-instances --db-instance-identifier "$DB_IDENTIFIER" --query "DBInstances[0].DBInstanceStatus" --output text --region "$AWS_REGION" 2>/dev/null)
fi

SNAPSHOT_COUNT=$(aws rds describe-db-snapshots --query "length(DBSnapshots[?contains(DBSnapshotIdentifier, '${PROJECT_NAME,,}-${ENV,,}')])" --output text --region "$AWS_REGION" 2>/dev/null || echo "0")

# Custos base (us-east-1)
BASTION_HOUR=0.0052  # t3.nano
BASTION_MONTH=$(echo "$BASTION_HOUR * 730" | bc)

RDS_HOUR=0.017  # db.t4g.micro
RDS_MONTH=$(echo "$RDS_HOUR * 730" | bc)

STORAGE_GB=0.08  # gp3
STORAGE_MONTH=$(echo "$STORAGE_GB * 20" | bc)

SNAPSHOT_GB=0.095
SNAPSHOT_MONTH=$(echo "$SNAPSHOT_GB * 20 * $SNAPSHOT_COUNT" | bc)

echo "📊 Recursos Atuais:"
echo "   • Bastion: $BASTION_STATE"
echo "   • RDS: $RDS_STATE"
echo "   • Snapshots: $SNAPSHOT_COUNT"
echo ""

echo "💵 Custos Mensais (us-east-1):"
echo ""
echo "┌─────────────────────────────────────────────────────┐"
echo "│ Recurso              Estado      Custo/mês          │"
echo "├─────────────────────────────────────────────────────┤"

if [ "$BASTION_STATE" == "running" ]; then
    printf "│ Bastion (t3.nano)    %-10s  \$%-6.2f           │\n" "ligado" "$BASTION_MONTH"
elif [ "$BASTION_STATE" == "stopped" ]; then
    printf "│ Bastion (t3.nano)    %-10s  \$%-6.2f           │\n" "desligado" 0
else
    printf "│ Bastion (t3.nano)    %-10s  \$%-6.2f           │\n" "não existe" 0
fi

if [ "$RDS_STATE" == "available" ]; then
    printf "│ RDS (db.t4g.micro)   %-10s  \$%-6.2f           │\n" "ligado" "$RDS_MONTH"
elif [ "$RDS_STATE" == "stopped" ]; then
    printf "│ RDS (db.t4g.micro)   %-10s  \$%-6.2f           │\n" "desligado" 0
else
    printf "│ RDS (db.t4g.micro)   %-10s  \$%-6.2f           │\n" "não existe" 0
fi

if [ "$RDS_STATE" != "não existe" ]; then
    printf "│ Storage (20GB gp3)   %-10s  \$%-6.2f           │\n" "ativo" "$STORAGE_MONTH"
fi

if [ "$SNAPSHOT_COUNT" -gt 0 ]; then
    printf "│ Snapshots (%dx20GB)   %-10s  \$%-6.2f           │\n" "$SNAPSHOT_COUNT" "ativo" "$SNAPSHOT_MONTH"
fi

echo "└─────────────────────────────────────────────────────┘"
echo ""

# Calcular total
TOTAL=0
[ "$BASTION_STATE" == "running" ] && TOTAL=$(echo "$TOTAL + $BASTION_MONTH" | bc)
[ "$RDS_STATE" == "available" ] && TOTAL=$(echo "$TOTAL + $RDS_MONTH + $STORAGE_MONTH" | bc)
[ "$RDS_STATE" == "stopped" ] && TOTAL=$(echo "$TOTAL + $STORAGE_MONTH" | bc)
[ "$SNAPSHOT_COUNT" -gt 0 ] && TOTAL=$(echo "$TOTAL + $SNAPSHOT_MONTH" | bc)

printf "💰 TOTAL ESTIMADO: \$%.2f/mês\n" "$TOTAL"
echo ""

echo "💡 Cenários de Economia:"
echo "   • Desligar RDS à noite (12h/dia): ~\$6.21/mês"
echo "   • Deletar RDS + manter snapshot: ~\$1.90/mês"
echo "   • Destruir tudo: \$0.00/mês"
