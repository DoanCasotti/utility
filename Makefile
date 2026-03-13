# ==============================================================================
# Makefile - Atalhos para comandos do projeto
# ==============================================================================

.PHONY: help validate deploy connect destroy status clean

help: ## Mostra esta ajuda
	@echo "📋 Comandos disponíveis:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Configura o projeto (copia .env.example)
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "✅ Arquivo .env criado. Edite-o antes de continuar."; \
	else \
		echo "⚠️  .env já existe"; \
	fi

validate: ## Valida ambiente e pré-requisitos
	@./validate.sh

deploy: ## Cria toda infraestrutura
	@./deploy.sh

connect: ## Conecta ao banco via túnel SSM
	@./connect.sh

destroy: ## Deleta toda infraestrutura
	@./destroy.sh

status: ## Verifica status dos recursos
	@scripts/check-status.sh

costs: ## Mostra estimativa de custos
	@scripts/cost-estimate.sh

backup: ## Cria backup completo (snapshot + config)
	@scripts/backup.sh

# Gerenciamento RDS
start-rds: ## Liga o RDS
	@scripts/start-rds.sh

stop-rds: ## Desliga o RDS
	@scripts/stop-rds.sh

hibernate-rds: ## Snapshot + Delete RDS
	@scripts/hibernate-rds.sh

restore-rds: ## Restaura RDS do snapshot
	@scripts/restore-rds.sh

# Gerenciamento Bastion
stop-bastion: ## Desliga Bastion
	@scripts/stop-bastion.sh

# Snapshots
list-snapshots: ## Lista todos snapshots
	@scripts/list-snapshots.sh

delete-all-snapshots: ## Deleta todos snapshots
	@scripts/delete-all-snapshots.sh

# Limpeza
clean: ## Remove arquivos temporários
	@echo "🧹 Limpando arquivos temporários..."
	@find . -name "*.log" -delete
	@find . -name ".DS_Store" -delete
	@echo "✅ Limpeza concluída"
