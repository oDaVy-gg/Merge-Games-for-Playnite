# Notas técnicas da migração P10 -> P11

O Playnite 11 não é uma recompilação simples do plugin atual.

Principais alterações aplicadas:

| Playnite 10 | Playnite 11 |
|---|---|
| PowerShell `.psm1` | C#/.NET 10 |
| `Guid` em IDs de metadados | `string` |
| `PluginId` + `GameId` | `LibraryId` + `LibraryGameId` |
| `Playtime : ulong` | `PlayTime : uint` |
| `LastActivity` | `LastPlayedDate` |
| `Added` | `AddedDate` |
| listas de IDs | `HashSet<string>` |
| `BufferedUpdate` | removido; usar APIs assíncronas/bulk |
| inicialização em construtor | `InitializeAsync` |
| pacote `.pext` | pacote `.pext2` |
| tipos separados Generic/Library/Metadata | um único tipo `Plugin` |

O núcleo foi isolado em `MergeEngine.cs` para que mudanças futuras da API do Playnite não exijam reescrever toda a lógica de mesclagem.
