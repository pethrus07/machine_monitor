# Machine Monitor

Sistema unificado de monitoramento industrial em Flutter, reunindo dois domínios
num único aplicativo:

- **Monitor de Produção** — status, OEE e produção horária de máquinas de chão de fábrica.
- **Bancada TEX “Anel Hídrico”** — operação e supervisão do ciclo de teste de estanqueidade.

A bancada TEX é integrada como um **tipo de máquina**: ao cadastrar um equipamento,
escolhe-se o tipo, e o app abre a tela e usa a fonte de dados correspondentes.

## Como rodar

```bash
flutter pub get
flutter run
```

## Real x Simulação

Toda a comunicação industrial usa **Modbus TCP/IP**. Para alternar entre CLP real
e simulação (útil para desenvolver sem hardware), mude `useRealModbus` em
`lib/app/app_config.dart`. Nenhuma tela precisa de alteração.

## Estrutura

```
lib/
├── main.dart            Ponto de entrada; injeta as fontes de dados.
├── app/                 Configuração central (AppConfig).
├── core/                Tema, pilha de rede Modbus e utilitários.
├── models/              Tipos de domínio imutáveis.
├── services/            Contratos das fontes de dados + implementações.
├── screens/             Telas (login, lista, detalhe do monitor, console TEX).
└── widgets/             Componentes visuais reutilizáveis.
```

## Documentação

A documentação técnica completa (arquitetura, comunicação, mapas de registradores,
padrões e guia de manutenção) está no arquivo
`Documentacao_Tecnica_Machine_Monitor.docx`.

## Dependências

`shared_preferences`, `fl_chart`, `intl`, `logging`.
