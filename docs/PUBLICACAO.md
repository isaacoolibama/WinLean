# Publicação — GitHub + LinkedIn

---

## 1. Subindo para o GitHub

Crie o repositório **público** vazio em `github.com/new` com o nome `WinLean` (sem README, sem .gitignore — já temos os dois).

```bash
cd caminho/para/WinLean

git init
git add .
git commit -m "feat: WinLean v1.1.0 - debloat reversivel para Windows com interface em Rust"
git branch -M main
git remote add origin https://github.com/isaacoolibama/WinLean.git
git push -u origin main
```

### Publicando a primeira release

O workflow `.github/workflows/release.yml` compila o binário Rust no `windows-latest` e anexa `winlean.exe` + `WinLean.zip` à release automaticamente quando você empurra uma tag:

```bash
git tag -a v1.1.0 -m "v1.1.0 - interface em Rust, i18n PT/EN e planos de energia"
git push origin v1.1.0
```

Isso importa: o `install.ps1` busca o asset `winlean.exe` da **latest release** pela API do GitHub. Enquanto não houver release, o instalador funciona normalmente, mas cai no menu PowerShell — vale rodar a tag antes de divulgar.

### Configuração do repositório

1. **About** (engrenagem à direita):
   *"Debloat, privacidade e performance para Windows 10/11. Interface em Rust, rollback por journal JSON, PT/EN."*
2. **Topics**: `windows` `powershell` `rust` `ratatui` `tui` `debloat` `windows11` `windows10` `privacy` `telemetry` `optimization` `sysadmin` `bloatware-removal` `registry-tweaks` `gaming`
3. **Issues** e **Discussions** ativados.
4. Adicione o repositório em **Destaques** no seu perfil do LinkedIn.

### Antes de divulgar

- [ ] Testar em VM: preset Trabalho em simulação, depois real, depois `R` (rollback)
- [ ] Testar o one-liner completo em uma máquina limpa
- [ ] Testar o seletor de plano de energia em desktop **e** em notebook (o caminho em que o Windows recusa o Desempenho máximo é o mais interessante de validar)
- [ ] Anotar em qual build testou (`winver`) e atualizar a tabela de compatibilidade
- [ ] Gravar um GIF da TUI com ScreenToGif e colocar logo abaixo do banner no README

O GIF da interface é o que mais converte em estrela num projeto de TUI. Vale mais que qualquer parágrafo.

---

## 2. Post para o LinkedIn

> Mídia sugerida: um GIF curto da TUI — navegar pela lista, abrir o seletor de energia com `P`, alternar idioma com `L`, iniciar e ver o log rolando. Uns 15 segundos.

---

### Versão principal

Todo mundo já rodou um script de debloat do Windows. O problema não é debloatar — é o que acontece uma semana depois, quando algo quebra e ninguém sabe o que foi alterado.

Foi esse incômodo que virou o **WinLean**, que acabei de publicar como open source.

Instala com uma linha no terminal:

`irm https://raw.githubusercontent.com/isaacoolibama/WinLean/main/install.ps1 | iex`

A diferença não está na lista de tweaks. Está em três decisões:

**1. Rollback de verdade, não ponto de restauração.**
Antes de aplicar qualquer coisa, o script grava um journal JSON com o valor anterior de cada chave, serviço e tarefa — e registra inclusive se a chave *existia*. Isso importa: no revert, um valor criado pelo script é removido, não sobrescrito com um "padrão" chutado. Uma tecla desfaz a execução inteira.

**2. Interface em Rust, motor em PowerShell.**
A TUI (ratatui) não altera nada: ela monta a linha de comando e delega ao script, que continua utilizável sozinho. Isso mantém uma única fonte de verdade sobre o que muda na máquina — e permite auditar o projeto sem ler uma linha de Rust. O binário tem poucas centenas de KB, abre instantâneo e não deixa processo residente.

**3. `Manual` em vez de `Disabled`.**
Desabilitar serviço é fácil; o difícil é não quebrar impressão, VPN, Bluetooth ou projeção três semanas depois. `Disabled` só entra onde não existe cenário legítimo em estação de trabalho. Windows Search, Spooler, Update e Defender não são tocados.

Deixei de fora o folclore que circula há anos. Memory Compression continua **ligada** — em máquina de 8 GB ela evita paginação, que custa muito mais caro que comprimir página. Prefetch **não** é apagado, porque o Windows só o reconstrói e os apps abrem mais devagar até lá.

Um detalhe que me deu trabalho e vale mencionar: o plano "Desempenho máximo" vem oculto no Windows e precisa ser duplicado antes de ativar — e muitos notebooks simplesmente recusam o esquema. O script duplica, ativa, **relê o plano ativo e confirma** que o hardware aceitou. Se recusou, avisa em vez de fingir que aplicou.

Interface e documentação em português e inglês, com português como padrão.

Código, release e docs aqui 👇
https://github.com/isaacoolibama/WinLean

Feedback, issue e PR são muito bem-vindos. Se rodar em algum build que eu não testei, me conta o resultado.

\#Windows #PowerShell #Rust #OpenSource #SysAdmin #Infraestrutura #TI #Automacao #Privacidade

---

### Versão curta

Publiquei o **WinLean**: debloat, privacidade e performance para Windows 10/11, com interface em Rust e uma linha de instalação.

`irm https://raw.githubusercontent.com/isaacoolibama/WinLean/main/install.ps1 | iex`

O detalhe que me fez escrever mais um debloater: **rollback de verdade**. Cada chave de registro, serviço e tarefa é gravada num journal JSON com o estado anterior antes de qualquer alteração. Uma tecla desfaz tudo.

→ TUI em Rust (ratatui) que só orquestra; o motor PowerShell continua auditável e utilizável sozinho
→ `Manual` em vez de `Disabled` onde desabilitar quebraria impressão, VPN ou Bluetooth
→ Search, Spooler, Update e Defender nunca são tocados
→ Nada de folclore: Memory Compression fica ligada e o Prefetch não é apagado
→ Seletor de plano de energia que **confere** se o hardware aceitou, em vez de fingir
→ PT e EN, padrão em português

MIT: https://github.com/isaacoolibama/WinLean

\#Windows #PowerShell #Rust #OpenSource #SysAdmin #TI

---

## 3. Dicas de alcance

- Poste entre **terça e quinta, 8h–10h** (horário de Brasília).
- Link no corpo do post, não no primeiro comentário — converte melhor para repositório.
- Responda **todos** os comentários nas duas primeiras horas; é o que sustenta o alcance.
- O one-liner no corpo do texto funciona como demonstração: quem é da área lê e já entende o nível de fricção do projeto.
- Duas ou três semanas depois, faça um follow-up com números reais: "X estrelas, Y issues, o que aprendi escrevendo TUI em Rust". Costuma performar melhor que o lançamento.
