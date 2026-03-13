# 🔧 Troubleshooting - Soluções para Problemas Comuns

## 🚨 Problemas no Deploy

### Erro: "Arquivo .env não encontrado"
**Solução:**
```bash
cp .env.example .env
nano .env  # Edite as configurações
```

### Erro: "Credenciais AWS inválidas"
**Solução:**
```bash
aws configure
# Ou para profile específico:
aws configure --profile meu-projeto
```

### Erro: "Infraestrutura já existe"
**Opções:**
1. Use outro PROJECT_NAME ou ENV no .env
2. Destrua a infraestrutura existente: `./destroy.sh`
3. Continue mesmo assim (não recomendado)

### Erro: "Senha não pode conter: @ / \" '"
**Solução:**
Use senha sem caracteres especiais problemáticos:
- ✅ Bom: `MinhaSenh@123` → `MinhaSenha123`
- ❌ Ruim: `Senha@123/test`

---

## 🔌 Problemas na Conexão

### Erro: "Porta 5433 já está em uso"
**Solução:**
```bash
# Descobrir processo usando a porta
lsof -ti:5433

# Matar processo
lsof -ti:5433 | xargs kill -9

# Ou mude LOCAL_PORT no .env
```

### Erro: "RDS está em estado: stopped"
**Solução:**
```bash
scripts/start-rds.sh
# Aguarde 2-5 minutos
./connect.sh
```

### Erro: "SSM Agent timeout"
**Causas:**
1. Bastion acabou de iniciar (aguarde 2-3 minutos)
2. IAM Role não está anexado
3. SSM Agent não está rodando

**Solução:**
```bash
# Verificar status
scripts/check-status.sh

# Recriar Bastion
scripts/delete-bastion.sh
# Edite deploy.sh e execute apenas a parte do Bastion
```

### Erro: "Session Manager Plugin não encontrado"
**Solução:**
```bash
# Linux
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
sudo dpkg -i session-manager-plugin.deb

# Mac
brew install --cask session-manager-plugin

# Windows
# Baixe: https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe
```

---

## 💰 Problemas de Custo

### "Custos inesperados"
**Verificar:**
```bash
scripts/check-status.sh
```

**Desligar tudo:**
```bash
scripts/stop-bastion.sh
scripts/stop-rds.sh
```

**Deletar tudo:**
```bash
./destroy.sh
```

### "RDS religou sozinho após 7 dias"
**Explicação:**
Limitação da AWS - RDS parado religa automaticamente após 7 dias.

**Solução:**
```bash
# Para períodos longos sem uso:
scripts/hibernate-rds.sh  # Snapshot + Delete
# Custo: ~$1.90/mês (apenas snapshot)

# Para restaurar:
scripts/restore-rds.sh
```

---

## 🔐 Problemas de Permissão

### Erro: "Sem permissão EC2/RDS/IAM"
**Solução:**
Seu usuário AWS precisa das seguintes permissões:
- `AmazonEC2FullAccess`
- `AmazonRDSFullAccess`
- `IAMFullAccess` (ou pelo menos criar roles)
- `AmazonSSMFullAccess`

**Verificar permissões:**
```bash
./validate.sh
```

---

## 🗑️ Problemas ao Destruir

### Erro: "VPC tem dependências"
**Solução:**
```bash
# O destroy.sh já trata isso, mas se falhar:
# 1. Delete manualmente no console AWS
# 2. Ou execute destroy.sh novamente
./destroy.sh
```

### "Snapshots não foram deletados"
**Solução:**
```bash
scripts/list-snapshots.sh
scripts/delete-all-snapshots.sh
```

---

## 📊 Verificação de Status

### Como saber o que está rodando?
```bash
scripts/check-status.sh
```

### Como ver logs de erro?
Os scripts mostram erros em tempo real. Se precisar de mais detalhes:
```bash
# Remova &> /dev/null dos comandos aws nos scripts
# Ou execute comandos AWS manualmente:
aws ec2 describe-instances --filters "Name=tag:Project,Values=DataApp"
```

---

## 🆘 Suporte

### Validar ambiente antes de começar:
```bash
./validate.sh
```

### Verificar status dos recursos:
```bash
scripts/check-status.sh
```

### Logs AWS CloudWatch:
- EC2: CloudWatch → Log Groups → `/aws/ec2/`
- RDS: CloudWatch → Log Groups → `/aws/rds/`

### Resetar tudo e começar do zero:
```bash
./destroy.sh
./deploy.sh
```
