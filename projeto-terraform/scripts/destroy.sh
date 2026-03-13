#!/bin/bash
set -euo pipefail

# ==============================================================================
# Script: Destruir Infraestrutura com Terraform
# ==============================================================================

echo "⚠️  ATENÇÃO: Isso deletará TODA a infraestrutura!"
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║  RECURSOS QUE SERÃO DELETADOS:                    ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  ✗ VPC e Subnets                                  ║"
echo "║  ✗ Security Groups                                ║"
echo "║  ✗ IAM Roles e Profiles                           ║"
echo "║  ✗ Bastion EC2                                    ║"
echo "║  ✗ RDS PostgreSQL                                 ║"
echo "╠════════════════════════════════════════════════════╣"
echo "║  💰 CUSTO FINAL: $0.00/mês                         ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
read -p "Confirmar destruição completa? (digite 'DELETAR'): " CONFIRM

if [ "$CONFIRM" != "DELETAR" ]; then
    echo "❌ Operação cancelada"
    exit 0
fi

echo ""
echo "🗑️ Destruindo infraestrutura..."

terraform destroy -auto-approve

echo ""
echo "✅ Infraestrutura completamente destruída!"
echo "💰 Custo 100% zerado - Nenhum recurso AWS restante"
