# ⚡ Quick Start - Deploy em 5 Minutos

## ✅ Arquivos Criados por Mim

```
✅ .gitignore           - Protege suas credenciais
✅ foundry.toml         - Configuração Foundry
✅ remappings.txt       - Mapeamento de bibliotecas
✅ script/Deploy.s.sol  - Script automatizado de deploy
✅ ENV_TEMPLATE.txt     - Template de variáveis de ambiente
✅ DEPLOYMENT.md        - Guia completo detalhado
```

---

## 🚀 O Que Você Precisa Fazer Agora

### 1️⃣ Instalar Foundry (1 minuto)

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Reinicie o terminal após a instalação.

### 2️⃣ Instalar Dependências (1 minuto)

```bash
cd /Users/kvbernal/Documents/src/KipuBankV3

forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install smartcontractkit/chainlink --no-commit
forge install foundry-rs/forge-std --no-commit
```

### 3️⃣ Obter ETH de Teste (2 minutos)

Visite: https://sepoliafaucet.com/

**Descubra seu endereço:**
```bash
# Se tiver MetaMask, use o endereço da sua carteira
# OU crie uma nova:
cast wallet new
```

### 4️⃣ Criar Arquivo .env (1 minuto)

```bash
# Copie o template
cp ENV_TEMPLATE.txt .env

# Edite com suas credenciais
nano .env
```

**Preencha:**
```bash
SEPOLIA_RPC_URL=https://rpc.sepolia.org
PRIVATE_KEY=sua_chave_privada_aqui
ETHERSCAN_API_KEY=sua_api_etherscan
```

**🔑 Obter Etherscan API Key:**
1. Acesse: https://etherscan.io/myapikey
2. Crie conta gratuita
3. Clique "Add" para gerar API key
4. Cole no `.env`

### 5️⃣ Deploy! (30 segundos)

```bash
# Compile
forge build

# Deploy + Verificação Automática
source .env && forge script script/Deploy.s.sol:DeployKipuBankV3 \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    -vvvv
```

---

## 🎯 Resultado Esperado

Você verá:

```
==================================
Deployment Successful!
==================================
Contract Address: 0x742d35Cc...
==================================

View on Sepolia Etherscan:
https://sepolia.etherscan.io/address/0x742d35Cc...
```

✅ **Contrato implantado e verificado!**

---

## 🆘 Ajuda Rápida

**Erro: "Insufficient funds"**
- Precisa de ~0.05 ETH na Sepolia
- Visite: https://sepoliafaucet.com/

**Erro: "command not found: forge"**
- Instale Foundry: `curl -L https://foundry.paradigm.xyz | bash`
- Execute: `foundryup`
- Reinicie o terminal

**Erro: "Failed to verify"**
- Aguarde 1-2 minutos
- Verifique manualmente: Veja `DEPLOYMENT.md`

---

## 📚 Mais Informações

- **Guia Completo:** Veja `DEPLOYMENT.md`
- **Template de .env:** Veja `ENV_TEMPLATE.txt`
- **Foundry Docs:** https://book.getfoundry.sh/

---

**Tudo pronto! Bora fazer o deploy! 🚀**

