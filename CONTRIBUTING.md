# Contribuindo / Contributing

> PT primeiro, EN abaixo.

## Regras do projeto

1. **Toda alteração precisa ser reversível.** Se um tweak não pode passar por
   `Set-RegValue`, `Set-ServiceStartup` ou `Disable-Task`, ele não entra.
2. **Justifique cada entrada.** Serviços e chaves de registro carregam uma
   descrição bilíngue no formato `portugues|english`. Ela aparece no log e no
   README; escreva pensando em quem ainda não conhece a chave.
3. **Prefira `Manual` a `Disabled`.** Desabilitar só é aceitável quando não existe
   cenário legítimo em estação de trabalho.
4. **Nada de folclore.** Se você não consegue apontar um efeito mensurável, deixe
   de fora. Desativar Memory Compression, apagar o Prefetch e "limpar a RAM" caem
   todos nesse balde.
5. **Traduza os dois lados.** Uma string nova em PT sem o par em EN (ou vice-versa)
   não passa na revisão. Na interface Rust, edite `ui/src/i18n.rs`.

## Enviando uma mudança

- Teste em VM: primeiro com simulação, depois de verdade, depois com `-Revert`.
- Informe em qual build testou (`winver`).
- Uma mudança lógica por pull request.
- O motor continua sendo um único arquivo, sem dependências externas.
- Na interface, mantenha a árvore de dependências enxuta. Hoje é só `ratatui`.

## Reportando um problema

Abra uma issue com:
- Edição e build do Windows
- O comando ou as opções que você usou
- O trecho relevante de `C:\ProgramData\WinLean\logs\winlean-*.log`

---

## Project rules (EN)

1. **Every change must be reversible.** If a tweak cannot go through
   `Set-RegValue`, `Set-ServiceStartup` or `Disable-Task`, it does not go in.
2. **Justify each entry.** Services and registry values carry a bilingual
   description in `portugues|english` form. It shows up in the log and the README.
3. **Prefer `Manual` over `Disabled`.** Disabling is only acceptable when there is
   no legitimate workstation scenario.
4. **No folklore.** If you cannot point to a measurable effect, leave it out.
5. **Translate both sides.** A new PT string without its EN pair (or vice versa)
   does not pass review. For the Rust interface, edit `ui/src/i18n.rs`.

Test on a VM with a dry run first, then for real, then with `-Revert`. Note the
build you tested on, one logical change per pull request.
