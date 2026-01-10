# Notas do Claude

## Configuração do Ambiente

- A máquina local (de onde os prompts são executados) **não é** a máquina de staging
- Conexão à máquina de staging é feita via **RDP (Remote Desktop Protocol)**
- O Claude Code está rodando na máquina local, mas operando sobre arquivos da máquina de staging remota

## Sobre o Projeto: StagingLocalRunner

### Objetivo
Configurar uma máquina local para permitir múltiplos deploys de branches simultâneos rodando localmente.

### Configuração da Máquina de Staging
- **OS**: Windows 11 Pro
- **Interface**: Tem interface gráfica instalada
- **Acesso**: Sem monitor nem teclado físicos - acesso exclusivamente via RDP
- Máquina funcionará como servidor de staging sem periféricos conectados

### Características do Projeto
- Integração com **Git** para gerenciar branches
- Integração com **Runner** para executar os deploys
- Capacidade de rodar **múltiplas branches simultaneamente** em ambiente local

### Contexto
Este projeto visa criar uma infraestrutura de staging local que permite testar e executar diferentes branches de código ao mesmo tempo, facilitando o desenvolvimento e testes paralelos.
