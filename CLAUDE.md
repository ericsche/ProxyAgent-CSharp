# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Prerequisite: install the Agents SDK plugin for C# / .NET

This repository is built on the Microsoft 365 Agents SDK for .NET. Before working
on any C# / .NET code, install the **`agents-for-net`** plugin from the Microsoft
Agents SDK plugin marketplace. Its skills load automatically when you work on
Agents SDK code and are a prerequisite for using the `proxy-agent-dev` skill on
.NET changes.

Run these commands inside Claude Code:

```
/plugin marketplace add microsoft/Agents
/plugin install agents-for-net@microsoft-agents-sdk
```

Verify with `/plugin`. Plugin source:
[microsoft/Agents › agent-plugins/agents-for-net](https://github.com/microsoft/Agents/tree/main/agent-plugins/agents-for-net).

The `agents-for-net` plugin provides these skills (activate automatically based on
what you're working on):

| Skill | Activates when... |
|-------|-------------------|
| `agents-sdk-dotnet` | Code imports `Microsoft.Agents.Hosting.AspNetCore`, `Microsoft.Agents.Builder`, or related packages, or when building a new agent in C# / .NET |
| `agents-sdk-dotnet-debugging` | Troubleshooting an Agents SDK agent in C# / .NET (build errors, auth failures, startup crashes, configuration issues) |
| `azure-agents-sdk-provision-dotnet` | Provisioning Azure Bot resources, Entra app registrations, identity credentials, or OAuth connections for a .NET agent |
| `bf-to-agents-sdk-dotnet-migration` | Migrating a Bot Framework .NET SDK bot (`Microsoft.Bot.Builder`) to Microsoft Agents SDK |
| `agents-sdk-dotnet-activityhandler-migration` | Migrating an Agents SDK bot from `ActivityHandler`/`TeamsActivityHandler` to `AgentApplication` routing |

## Required reading before any work

Before doing any work in this repository — understanding the project, explaining
the architecture, onboarding, building or modifying the proxy agent, wiring a new
backend SDK, configuring SSO, updating Bicep infrastructure, or troubleshooting —
**read the `proxy-agent-dev` skill**:

- [.agents/skills/proxy-agent-dev/SKILL.md](.agents/skills/proxy-agent-dev/SKILL.md)

That skill is the authoritative guide for this codebase. Follow its principles
(no secrets in source, secure secret storage, prefer managed identity, user
identity propagation, Bot Service as control plane only, replaceable backend,
streaming-first) on every change.

## Project summary

This is **ProxyAgent-CSharp** — a proxy agent that connects any external AI agent
to Microsoft 365 Copilot and Teams via direct SDK integration. The proxy handles
Teams/M365 Copilot transport, SSO, and streaming; the backend AI SDK is the only
part you replace.

Key locations:

- `AzureAgentToM365ATK/Agents/AzureAgent.cs` — backend SDK integration point
- `AzureAgentToM365ATK/Program.cs` — host wiring
- `M365Agent/` — Microsoft 365 Agents Toolkit project (manifest, infra, env, scripts)
- `M365Agent/infra/` — Bicep infrastructure
