# Roblox + Rojo Game

Bu VS Code va Roblox Studio uchun toza Rojo loyiha muhiti.

## Papkalar

- `src/Workspace` -> `Workspace`
- `src/ReplicatedFirst` -> `ReplicatedFirst`
- `src/ReplicatedStorage` -> `ReplicatedStorage`
- `src/ServerScriptService` -> `ServerScriptService`
- `src/ServerStorage` -> `ServerStorage`
- `src/StarterGui` -> `StarterGui`
- `src/StarterPlayer` -> `StarterPlayer`

## Rojo serverni ishga tushirish

VS Code terminalida:

```bash
./tools/bin/rojo serve
```

Yoki VS Code ichida `Terminal > Run Task... > Rojo: Serve`.

Keyin Roblox Studio'da Rojo pluginni ochib, `localhost` serverga ulan.

## Boshlang'ich scriptlar

- Server scripts: `src/ServerScriptService/*.server.luau`
- Client scripts: `src/StarterPlayer/StarterPlayerScripts/*.client.luau`
- Models: `*.rbxm`
