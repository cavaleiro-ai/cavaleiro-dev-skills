# Guia do Cavaleiro Dev Skills (pt-BR)

Este é o guia completo, em português, do **Cavaleiro Dev Skills**, mantido
pela Cavaleiro AI.

Sumário:

1. [O que é e para quem](#1-o-que-é-e-para-quem)
2. [Arquitetura](#2-arquitetura)
3. [Instalação passo a passo](#3-instalação-passo-a-passo)
4. [Primeiros passos](#4-primeiros-passos)
5. [Exemplos práticos](#5-exemplos-práticos)
6. [Configuração](#6-configuração)
7. [Solução de problemas](#7-solução-de-problemas)
8. [Como contribuir](#como-contribuir)

---

## 1. O que é e para quem

O Cavaleiro Dev Skills é uma **biblioteca de skills** para agentes de código
(Claude Code, Codex, Cursor, Gemini CLI, OpenCode, Pi, Hermes, Kimi, Muse e
outros). Uma *skill* é um arquivo Markdown (`SKILL.md`) com instruções que o
agente segue quando a situação pede: antes de construir, ele faz perguntas e
escreve um desenho; antes de implementar, escreve um plano; ao implementar,
escreve o teste primeiro; ao depurar, procura a causa raiz; ao terminar,
verifica e pergunta como integrar.

O resultado é um **método de desenvolvimento**, não só um conjunto de dicas:
as skills se chamam umas às outras (`superpowers:writing-plans`,
`superpowers:test-driven-development` …) e um pequeno *bootstrap* —
a skill `using-superpowers`, injetada no início de cada sessão — garante que o
agente procure a skill certa antes de responder.

**Para quem é:**

- quem usa agentes de código no dia a dia e quer que eles planejem, testem e
  revisem em vez de sair escrevendo código;
- equipes que querem um fluxo previsível (desenho → plano → TDD → revisão →
  merge) que funcione igual em várias ferramentas;
- quem já usa o projeto original e quer as correções desta versão (veja o
  [changelog](../../CHANGELOG.md)) sem mudar nenhum nome, comando ou caminho.

**O que este projeto muda em relação à versão 7.0.0 do projeto original:**
correções verificadas nos hooks, scripts e skills; um executor de testes e um
validador estático; segurança do fork (nada publica em nome do projeto
original); documentação em português. Os identificadores são os mesmos — o
plugin ainda se chama `superpowers` (veja [Compatibilidade](../../README.pt-BR.md#compatibilidade)).

## 2. Arquitetura

O projeto não é um aplicativo. São três camadas:

1. **As skills** (`skills/<nome>/SKILL.md`, com prompts, referências e scripts
   auxiliares). São 15. A `using-superpowers` é o bootstrap.
2. **A cola por ferramenta** — manifestos e pequenos plugins que registram as
   skills e injetam o bootstrap na sessão.
3. **Ferramentas e testes** — scripts de manutenção (`scripts/`) e testes
   (`tests/`).

```text
                 ┌───────────────────────────────────────────────────┐
                 │  skills/<nome>/SKILL.md  (+ prompts e scripts)    │
                 │  using-superpowers = bootstrap da sessão          │
                 └──────────────────────▲────────────────────────────┘
                                        │ lido no início da sessão
          ┌─────────────────────────────┼─────────────────────────────┐
          │                             │                             │
   Hook de shell                 Plugin em processo            Só manifesto
   (Claude Code, Copilot CLI,    (OpenCode: .opencode/,        (Kimi: sessionStart,
    Qwen, Droid, Cursor, Muse)    Pi: .pi/, Hermes:             Gemini: GEMINI.md,
          │                       .hermes-plugin/)              Codex, Antigravity,
          ▼                             │                       Devin: pasta skills/)
   hooks/run-hook.cmd                   │
   (no Windows procura o                │
    Git Bash; no Unix é bash)           │
          ▼                             ▼
   hooks/session-start ──►  contexto injetado na sessão (JSON do hook,
                            mensagem de usuário ou contexto do sistema)
```

**Fluxo de uma sessão:** a ferramenta inicia → o hook ou plugin lê
`skills/using-superpowers/SKILL.md` → injeta o conteúdo → o modelo passa a
procurar skills antes de responder → as skills de processo encadeiam umas às
outras e chamam scripts auxiliares.

**Componentes principais:**

| Componente | Função |
|------------|--------|
| `skills/brainstorming/` | Extrai a intenção antes de construir; tem um companheiro visual opcional (servidor local `server.cjs`, iniciado por `scripts/start-server.sh`) |
| `skills/writing-plans/` | Transforma o desenho em tarefas pequenas, com código e verificação |
| `skills/subagent-driven-development/` | Executa o plano com um subagente por tarefa e revisão após cada uma. Scripts: `sdd-workspace` (workspace por plano em `.superpowers/sdd/`), `task-brief` (extrai uma tarefa do plano), `review-package` (pacote de diff para o revisor) |
| `skills/executing-plans/` | Executa o plano na própria sessão. Scripts: `task-start`, `task-done` (roda os testes e registra no ledger) |
| `skills/using-git-worktrees/`, `skills/finishing-a-development-branch/` | Isolamento em worktree e decisão final (merge, PR, manter, descartar) |
| `skills/test-driven-development/`, `skills/systematic-debugging/`, `skills/verification-before-completion/` | Disciplina de teste, depuração e verificação |
| `skills/diagnosing-superpowers/` | Analisa a transcrição de uma sessão que deu errado e prepara um relato |
| `hooks/` | Bootstrap para ferramentas com hook de shell |
| Manifestos (`.claude-plugin/`, `.codex-plugin/`, `.cursor-plugin/`, `.muse-plugin/` …) | Id do plugin (`superpowers`), versão, caminhos de skills e hooks |
| `tests/run-plugin-tests.sh` | Executa todas as suítes que não precisam de LLM |

**Pontos de extensão:** uma skill nova é um diretório em `skills/` (e uma
entrada em `.muse-plugin/plugin.json`); uma ferramenta nova ganha um manifesto
e, se precisar, um módulo de plugin (veja
[porting-to-a-new-harness.md](../porting-to-a-new-harness.md), em inglês). O
mapeamento de nomes de ferramentas por harness fica em
`skills/using-superpowers/references/*-tools.md`.

## 3. Instalação passo a passo

Instale **ou** o projeto original **ou** o Cavaleiro Dev Skills em cada
ferramenta — os dois usam o mesmo id de plugin e os mesmos nomes de skill. As
entradas `superpowers` dos marketplaces oficiais instalam o projeto original.

### 3.1 Pré-requisitos por sistema

| Sistema | O que instalar | Observação |
|---------|----------------|------------|
| **Windows 10/11** | [Git for Windows](https://git-scm.com/download/win) (traz o Git Bash) e a sua ferramenta de agente | O hook procura o `bash.exe` do Git for Windows em `C:\Program Files\Git`, em `%LOCALAPPDATA%\Programs\Git` ou no `PATH`. Sem bash o hook sai em silêncio e o plugin funciona sem o bootstrap. Para o companheiro visual, instale também o [Node.js](https://nodejs.org/) |
| **macOS** | Git (vem com as Command Line Tools: `xcode-select --install`) e a sua ferramenta | Node.js para o companheiro visual (`brew install node`) |
| **Linux** | `git` e `bash` (já presentes na maioria das distribuições) e a sua ferramenta | No Debian/Ubuntu o `/bin/sh` é o dash; esta versão roda o hook do Muse com `bash`, então funciona |

Opcional para quem vai rodar os testes: Python 3 com `pytest`, `jq`, `yq`
(mikefarah), Graphviz (`dot`), `rsync`, `zip`/`unzip` e ShellCheck.

### 3.2 Claude Code (Windows, macOS e Linux)

Dentro do Claude Code:

```text
/plugin marketplace add cavaleiro-ai/cavaleiro-dev-skills
/plugin install superpowers@superpowers-dev
```

Reinicie a sessão. No Windows, confira se o Git for Windows está instalado
(passo 3.1): o Claude Code executa o hook pelo `hooks/run-hook.cmd`.

### 3.3 Outras ferramentas

Os comandos de cada ferramenta (Antigravity, Codex, Cursor, Devin, Droid,
Gemini, Copilot CLI, Kimi, OpenCode, Pi, Qwen, Hermes, Muse) estão no
[README em português](../../README.pt-BR.md#instalação). Os mais comuns:

```bash
# Gemini CLI
gemini extensions install https://github.com/cavaleiro-ai/cavaleiro-dev-skills

# Pi
pi install git:github.com/cavaleiro-ai/cavaleiro-dev-skills

# Hermes
hermes plugins install cavaleiro-ai/cavaleiro-dev-skills --enable
```

Para o OpenCode, peça ao próprio OpenCode:

```text
Fetch and follow instructions from https://raw.githubusercontent.com/cavaleiro-ai/cavaleiro-dev-skills/refs/heads/main/.opencode/INSTALL.md
```

### 3.4 A partir de um clone (desenvolvimento)

```bash
git clone https://github.com/cavaleiro-ai/cavaleiro-dev-skills.git
cd cavaleiro-dev-skills
```

No Windows, abra o **Git Bash** para os comandos acima. Depois aponte a sua
ferramenta para o clone (por exemplo `pi -e /caminho/para/cavaleiro-dev-skills`
ou `muse plugins install ./cavaleiro-dev-skills`).

### 3.5 Verifique a instalação

Abra uma sessão nova e envie exatamente:

```text
Let's make a react todo list
```

Uma instalação funcionando aciona a skill **brainstorming** antes de escrever
qualquer código: o agente começa com perguntas, não com arquivos.

## 4. Primeiros passos

1. **Comece pelo que você quer construir.** Diga em linguagem natural. O agente
   usa o `brainstorming`: faz perguntas uma de cada vez, devolve o entendimento
   e, num projeto maior, escreve um documento de desenho para você aprovar.
2. **Aprove o desenho.** O agente oferece uma worktree isolada
   (`using-git-worktrees`) — aceite para proteger o seu branch atual.
3. **Deixe o plano ser escrito.** O `writing-plans` cria tarefas de 2 a 5
   minutos com caminhos de arquivo, código e o comando de verificação de cada
   passo. Leia o plano: é ele que o agente vai seguir.
4. **Escolha como executar.** Com subagentes (`subagent-driven-development`,
   mais rigoroso: revisão a cada tarefa) ou na própria sessão
   (`executing-plans`, mais barato: uma revisão no fim).
5. **Acompanhe pelo ledger.** O progresso fica em
   `.superpowers/sdd/<plano>/progress.md`, ignorado pelo git. Ele sobrevive à
   compactação do contexto.
6. **Finalize.** O `finishing-a-development-branch` roda os testes e pergunta:
   merge local, pull request, manter o branch ou (só se você pedir) descartar.

Dica: você pode pedir uma skill pelo nome — "use a skill systematic-debugging"
— ou deixar que o agente escolha.

## 5. Exemplos práticos

### 5.1 Uma funcionalidade nova num projeto existente

```text
Quero adicionar exportação em CSV na tela de relatórios.
```

O agente pergunta formato, colunas e volume de dados; propõe o desenho; cria a
worktree `.worktrees/exportacao-csv`; escreve o plano; implementa com TDD
(cada teste é visto falhando antes do código); revisa; e no fim pergunta se
você quer merge ou PR.

### 5.2 Depurar um teste que falha de vez em quando

```text
O teste test_checkout falha uma vez a cada dez execuções. Descubra por quê.
```

O `systematic-debugging` faz o agente reproduzir, levantar hipóteses e testar
uma de cada vez antes de mexer em código. Para testes que poluem uns aos outros,
há o script `skills/systematic-debugging/find-polluter.sh`.

### 5.3 Projeto do zero (greenfield)

Num diretório vazio, a Task 1 do plano costuma ser `git init`. Nesta versão os
scripts auxiliares funcionam antes do repositório existir:

```bash
bash <skill-dir>/scripts/task-brief docs/plano.md 1
# sdd-workspace: not inside a git repository; using the current directory (...)
# wrote .../.superpowers/sdd/plano/task-1-brief.md: 12 lines
```

`<skill-dir>` é o diretório da skill (a pasta do `SKILL.md`). Rode os
auxiliares **a partir da pasta do projeto**, nunca de dentro da pasta da skill:
eles usam o git do diretório atual.

### 5.4 Ver os fluxogramas de uma skill

```bash
node skills/writing-skills/render-graphs.js skills/subagent-driven-development
# gera skills/subagent-driven-development/diagrams/*.svg (precisa do Graphviz)
```

### 5.5 Diagnosticar uma sessão que deu errado

```text
figure out what went wrong with superpowers in this session
```

A skill `diagnosing-superpowers` lê a transcrição, mostra a evidência linha a
linha e, se você quiser, prepara um relato sanitizado para as
[issues deste repositório](https://github.com/cavaleiro-ai/cavaleiro-dev-skills/issues).

## 6. Configuração

Não há arquivo de configuração. Tudo é por variável de ambiente ou pelas
instruções que você dá ao agente.

| O quê | Como |
|-------|------|
| Desligar a telemetria do companheiro visual | `SUPERPOWERS_DISABLE_TELEMETRY=1` (também valem `DISABLE_TELEMETRY` e `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` do Claude Code). Por padrão o logotipo é carregado do site dos autores originais com a versão na URL; nada do seu projeto é enviado |
| Companheiro visual em outro host/porta | `start-server.sh --host 0.0.0.0 --url-host meu-host`, `--project-dir <pasta>` (aceita caminho relativo nesta versão), `--idle-timeout-minutes <n>`, `--foreground`/`--background` |
| Pasta das worktrees | Declare a preferência nas instruções do agente (por exemplo no `CLAUDE.md`/`AGENTS.md` do projeto); senão ele usa `.worktrees/` (ou `worktrees/`, se já existir) e confirma que a pasta está no `.gitignore` |
| Preferência de worktree | Diga nas instruções se quer sempre, nunca ou perguntar; o agente respeita sem perguntar de novo |
| Sincronizar com um marketplace do Codex (mantenedores) | `CODEX_PLUGIN_FORK=<dono>/<repo>` antes de `scripts/sync-to-codex-plugin.sh` (sem padrão, de propósito); `-n` faz só a simulação |
| Versão dos manifestos (mantenedores) | `bash scripts/bump-version.sh --check` / `X.Y.Z` (precisa de `jq` e `yq`) |

## 7. Solução de problemas

| Sintoma | Causa provável | O que fazer |
|---------|----------------|-------------|
| As skills não disparam; o agente vai direto ao código | Bootstrap não injetado | Abra uma sessão nova; confirme a instalação (passo 3.5). No Windows, instale o Git for Windows — sem bash o hook sai em silêncio |
| Skills duplicadas ou hooks rodando duas vezes | Projeto original e Cavaleiro Dev Skills instalados juntos | Desinstale um dos dois |
| Erro "Bad substitution" no Muse | Versão antiga rodando o hook com `sh` (dash) | Atualize para esta versão (o manifesto usa `bash`) |
| `review-package: not inside a git repository` | Comando rodado fora do projeto, ou projeto ainda sem `git init`/commit | Rode a partir da pasta do projeto; num projeto novo, não há o que revisar até existir um commit |
| `bad BASE` ou diff do repositório errado | Script rodado de dentro da pasta da skill | Rode `bash <skill-dir>/scripts/review-package …` a partir do projeto |
| O brief da Task 6 traz a Task 6b junto | Versão antiga do `task-brief` | Corrigido nesta versão |
| `start-server.sh` diz "Server failed to start" com `--project-dir .` | Versão antiga com caminho relativo | Corrigido nesta versão; ou passe caminho absoluto |
| Companheiro visual não abre no Windows | O Git Bash encerra processos em segundo plano | O script já roda em primeiro plano no Windows; deixe o terminal aberto |
| `render-graphs.js` diz "graphviz (dot) not found" | Graphviz ausente | `winget install Graphviz.Graphviz` (Windows), `brew install graphviz` (macOS), `apt install graphviz` (Linux) |
| `bump-version.sh` falha com "no matches found" no Windows | Versão antiga com jq/yq nativos do Windows (CRLF) | Corrigido nesta versão |
| A worktree foi removida e o ledger sumiu | O git não protege arquivos ignorados | Esta versão verifica `.superpowers/sdd/` antes de remover e pergunta |

Ainda com problemas? Use a skill `diagnosing-superpowers` e abra uma issue em
<https://github.com/cavaleiro-ai/cavaleiro-dev-skills/issues>. Falhas de
segurança vão pelo canal privado descrito no [SECURITY.md](../../SECURITY.md).

## Como contribuir

1. **Leia as regras** no [CONTRIBUTING.md](../../CONTRIBUTING.md) (em inglês).
   Em resumo: skills são código (não reescreva texto que molda comportamento
   sem evidência), identificadores são contrato (o plugin continua
   `superpowers`), zero dependências, e, se o problema também existir no
   projeto original, diga isso na issue ou no PR — nunca envie mudanças do
   fork para lá.
2. **Rode os testes** (no Windows, pelo Git Bash):

   ```bash
   bash tests/run-plugin-tests.sh            # todas as suítes sem LLM
   bash tests/run-plugin-tests.sh --list     # suítes e ferramentas exigidas
   node tests/skills/validate-skills.mjs     # skills e manifestos
   bash tests/skills/test-skill-snippets.sh  # comandos impressos pelas skills
   ```

   Suítes cujas ferramentas opcionais faltam aparecem como SKIP.
3. **Correção de bug = teste de regressão** que falha antes e passa depois.
   Nunca enfraqueça um teste existente para ficar verde.
4. **Abra o pull request contra `main`**, preencha o
   [modelo de PR](../../.github/PULL_REQUEST_TEMPLATE.md), informe o modelo e a
   ferramenta usados e acrescente uma linha em **Unreleased** no
   [CHANGELOG.md](../../CHANGELOG.md).
5. **Primeiro commit a partir do Windows:** restaure os bits de execução dos
   scripts, como descrito em
   [ENGINEERING.md](ENGINEERING.md#7-executable-bits).

Ao participar, você concorda com o [Código de Conduta](../../CODE_OF_CONDUCT.md).
