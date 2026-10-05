# Merge Games — migração para Playnite 11

Esta pasta contém a migração do Merge Games de PowerShell para **C#/.NET 10**, a direção recomendada para o Playnite 11.

## Estado

- [x] núcleo de mesclagem portado de PowerShell para C#
- [x] modelo atualizado para IDs `string`
- [x] `Playtime` P10 -> `PlayTime` P11
- [x] `LastActivity` -> `LastPlayedDate`
- [x] `Added` -> `AddedDate`
- [x] `PluginId/GameId` -> `LibraryId/LibraryGameId`
- [x] coleções de metadados atualizadas para `HashSet<string>`
- [x] mídia atualizada para `Game.MediaFiles`
- [x] código estruturado para inicialização assíncrona
- [ ] conectar a janela WPF de seleção campo a campo
- [ ] conectar escrita/remoção à `ILibraryApi` da build P11 instalada
- [ ] portar migração/backup do Extra Metadata Loader para o mecanismo de comunicação entre plugins do P11
- [ ] gerar pacote final `.pext2` com Toolbox do Playnite 11

## Por que uma pasta/branch separada?

O Playnite 10 usa uma API completamente diferente. Manter o código P10 estável na branch `main` evita quebrar usuários atuais, enquanto a branch `playnite11` evolui para a nova SDK.

## Compilação

O Playnite 11 usa **.NET 10** e o SDK P11 deve ser obtido pelo template oficial do Toolbox.

O fluxo recomendado pela documentação do Playnite é:

```text
Toolbox.exe new plugin "OpenAI e oDaVy_gg" "Merge Games" <pasta>
```

Depois, copie os arquivos desta pasta para o projeto criado pelo Toolbox e mantenha o `nuget.config`/referências geradas pelo template. Isso evita fixar aqui uma URL de feed ou versão de SDK que ainda pode mudar durante a fase alpha/beta do Playnite 11.

## Regra do projeto

A partir desta migração:
- **Playnite 10:** PowerShell, branch `main`
- **Playnite 11:** C#/.NET 10, branch `playnite11`
