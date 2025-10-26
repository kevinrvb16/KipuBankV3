# 🚀 Guia de Deploy do KipuBankV3

## 📋 Pré-requisitos

- [x] Foundry instalado (`curl -L https://foundry.paradigm.xyz | bash && foundryup`)
- [ ] ETH de teste na Sepolia
- [ ] RPC URL (Infura, Alchemy ou público)
- [ ] Etherscan API Key

---

## 🎯 Passo 1: Obter ETH de Teste

Visite um dos faucets da Sepolia:

- 🔗 https://sepoliafaucet.com/
- 🔗 https://www.infura.io/faucet/sepolia  
- 🔗 https://faucet.quicknode.com/ethereum/sepolia

**Endereço da sua wallet:** Extraia da sua private key usando:
```bash
cast wallet address --private-key YOUR_PRIVATE_KEY
```

---

## 🔑 Passo 2: Configurar Credenciais

### 2.1. Copie o arquivo de exemplo
```bash
cp .env.example .env
```

### 2.2. Edite o arquivo `.env`

```bash
nano .env  # ou use seu editor preferido
```

**Preencha com suas credenciais:**

```bash
# RPC URL (escolha uma opção):
# Opção 1: Infura (precisa criar conta em infura.io)
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/SUA_API_KEY_AQUI

# Opção 2: RPC público (sem necessidade de cadastro)
# SEPOLIA_RPC_URL=https://rpc.sepolia.org

# Sua Private Key (SEM o prefixo 0x)
PRIVATE_KEY=sua_private_key_aqui

# Etherscan API Key (criar em etherscan.io/myapikey)
ETHERSCAN_API_KEY=sua_etherscan_api_key
```

**⚠️ IMPORTANTE:** 
- NUNCA compartilhe seu arquivo `.env`
- NUNCA faça commit da sua private key
- O arquivo `.env` já está no `.gitignore`

### 2.3. Obter Etherscan API Key

1. Acesse: https://etherscan.io/myapikey
2. Faça login/crie uma conta gratuita
3. Clique em "Add" para criar uma nova API key
4. Copie a key gerada e cole no `.env`

---

## 🏗️ Passo 3: Instalar Dependências

```bash
# Instalar bibliotecas OpenZeppelin e Chainlink
forge install OpenZeppelin/openzeppelin-contracts --no-commit
forge install smartcontractkit/chainlink --no-commit
```

---

## ⚙️ Passo 4: Compilar o Contrato

```bash
forge build
```

Você deve ver:
```
[⠊] Compiling...
[⠒] Compiling 1 files with 0.8.30
[⠆] Solc 0.8.30 finished in XX.XXs
Compiler run successful!
```

---

## 🚀 Passo 5: Deploy do Contrato

### Método 1: Deploy com Verificação Automática (Recomendado)

```bash
source .env && forge script script/Deploy.s.sol:DeployKipuBankV3 \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    -vvvv
```

### Método 2: Deploy Manual (sem script)

```bash
source .env && forge create --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --constructor-args $ETH_USD_FEED $MAX_WITHDRAWAL $BANK_CAP $UNIVERSAL_ROUTER $PERMIT2 $USDC \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    src/KipuBankV3.sol:KipuBankV3
```

---

## ✅ Passo 6: Verificar Deploy

Após o deploy, você verá algo como:

```
==================================
Deployment Successful!
==================================
Contract Address: 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb
==================================
```

**Copie o endereço do contrato e visite:**
```
https://sepolia.etherscan.io/address/SEU_CONTRACT_ADDRESS
```

Você deve ver:
- ✅ Ícone verde de verificado
- Aba "Contract" com código-fonte
- Abas "Read Contract" e "Write Contract"

---

## 🔍 Verificação Manual (se necessário)

Se a verificação automática falhar:

```bash
source .env && forge verify-contract \
    SEU_CONTRACT_ADDRESS \
    src/KipuBankV3.sol:KipuBankV3 \
    --chain sepolia \
    --constructor-args $(cast abi-encode "constructor(address,uint256,uint256,address,address,address)" $ETH_USD_FEED $MAX_WITHDRAWAL $BANK_CAP $UNIVERSAL_ROUTER $PERMIT2 $USDC) \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --watch
```

---

## 🧪 Passo 7: Testar o Contrato

### Testar no Etherscan (Interface Web)

1. Vá para: `https://sepolia.etherscan.io/address/SEU_CONTRACT_ADDRESS#writeContract`
2. Clique em "Connect to Web3" (MetaMask)
3. Teste funções:
   - `depositEth()` - envie 0.01 ETH
   - `getMyVaultBalance()` - verifique seu saldo

### Testar via Cast (CLI)

```bash
# Ver saldo
cast call SEU_CONTRACT_ADDRESS "getMyVaultBalance()(uint256)" --rpc-url $SEPOLIA_RPC_URL

# Depositar ETH (0.01 ETH = 10000000000000000 wei)
cast send SEU_CONTRACT_ADDRESS "depositEth()" --value 0.01ether --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
```

---

## 📊 Informações Úteis

### Endereços Configurados (Sepolia)

| Contrato | Endereço |
|----------|----------|
| ETH/USD Price Feed | `0x694AA1769357215DE4FAC081bf1f309aDC325306` |
| Universal Router | `0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD` |
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |
| USDC | `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238` |

### Configurações do Banco

- **Max Withdrawal**: 10,000 USDC
- **Bank Cap**: 1,000,000 USDC

---

## 🐛 Troubleshooting

### Erro: "Insufficient funds"
- Verifique se tem ETH de teste suficiente
- Um deploy custa ~0.02-0.05 ETH

### Erro: "Failed to verify"
- Aguarde alguns minutos após o deploy
- Tente verificação manual
- Verifique se ETHERSCAN_API_KEY está correto

### Erro: "InvalidAddress" no deploy
- Verifique se todas as variáveis do .env estão corretas
- Confirme que está usando endereços da Sepolia

### Erro de compilação
```bash
# Limpar cache e recompilar
forge clean
forge build
```

---

## 🎉 Próximos Passos

Após deploy bem-sucedido:

1. ✅ Salve o endereço do contrato
2. ✅ Compartilhe o link do Etherscan
3. ✅ Teste as funções principais
4. ✅ Configure roles se necessário (ADMIN_ROLE, etc)

---

## 📝 Comandos Rápidos

```bash
# Compilar
forge build

# Testar
forge test

# Deploy + Verificação
source .env && forge script script/Deploy.s.sol:DeployKipuBankV3 --rpc-url $SEPOLIA_RPC_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv

# Ver gas report
forge test --gas-report

# Ver coverage
forge coverage
```

---

## 📚 Recursos

- 📖 Foundry Book: https://book.getfoundry.sh/
- 🔗 Sepolia Etherscan: https://sepolia.etherscan.io
- 💧 Sepolia Faucet: https://sepoliafaucet.com/
- 🔑 Etherscan API Keys: https://etherscan.io/myapikey

---

**Sucesso no seu deploy! 🚀**

