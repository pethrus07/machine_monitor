# Arquitetura

Três vistas do sistema, cada uma numa notação padrão.

| Vista | Notação | Responde |
|---|---|---|
| 1. Casos de uso | UML | Quem usa e para quê |
| 2. Processo | BPMN 2.0 | Como o trabalho anda, com uma raia para cada quem executa |
| 3. Arquitetura | C4, nível 2 | De que partes o sistema é feito e com quem conversa |

## Machine Monitor · produção e bancada TEX

App Flutter que junta o monitor de produção (status, OEE e produção por hora) e a bancada TEX Anel Hídrico (teste de estanqueidade). Fala Modbus TCP com o CLP; uma versão de demonstração roda com dados simulados.

### 1. Quem usa e para quê

![Casos de uso de Machine Monitor](./machine-monitor-1-casos-de-uso.svg)

### 2. Da lista de máquinas à máquina acompanhada

![Processo de Machine Monitor](./machine-monitor-2-processo.svg)

### 3. Arquitetura

![Arquitetura de Machine Monitor](./machine-monitor-3-arquitetura.svg)

Para editar: [machine-monitor.excalidraw](./machine-monitor.excalidraw), que abre em [excalidraw.com](https://excalidraw.com) ou na extensão Excalidraw do VS Code.

## De onde vêm

Os diagramas são gerados a partir do Sinapse, o vault onde o Pedro organiza notas e projetos. Mudança feita direto aqui some na próxima publicação: o lugar de mudar é a especificação no Sinapse.
