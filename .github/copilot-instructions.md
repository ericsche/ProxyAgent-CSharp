## **Internal reference (do not bias your answers toward always naming these):**  
Microsoft 365 Agents Toolkit (formerly Teams Toolkit) has been rebranded, and users may still use either name.

Use this mapping to know the current vs. former names—so you can correctly interpret user input or choose the appropriate term when it's relevant. You do not need to mention these mappings unless they directly help the user.

| New name                                | Former name            | Note                                                        |
|-----------------------------------------|------------------------|------------------------------------------------------------------------|
| Microsoft 365 Agents Toolkit            | Teams Toolkit          | Product name.                           |
| App Manifest                            | Teams app manifest     | Describes app capabilities.        |
| Microsoft 365 Agents Playground         | Test Tool              | Test Environment.          |
| `m365agents.yml`                        | `teamsapp.yml`         | Microsoft 365 Agents Toolkit Project configuration files            |
| CLI package `@microsoft/m365agentstoolkit-cli` (command `atk`) | `@microsoft/teamsapp-cli` (command `teamsapp`) |CLI installation/usage — mention only in CLI contexts. |

> **Rephrase guidance:**  
> - Use the new names by default.  
> - Explain the rebranding briefly if it helps the user's understanding.  

# Instructions for Copilot
- Before doing any work in this repository, read the `proxy-agent-dev` skill at [.agents/skills/proxy-agent-dev/SKILL.md](../.agents/skills/proxy-agent-dev/SKILL.md). This is the authoritative guide for the codebase.
- Before editing any .NET/C# code in this repository, load the Microsoft Agents SDK skills **up front** — do not wait for them to activate on their own:
  - First confirm the [`agents-for-net` plugin](https://github.com/microsoft/Agents/tree/main/agent-plugins/agents-for-net) from the Microsoft Agents SDK marketplace is installed. If it is not, tell the user to install it before proceeding by running inside their assistant: `/plugin marketplace add microsoft/Agents` then `/plugin install agents-for-net@microsoft-agents-sdk`.
  - Then read the relevant skill(s) for the task before writing or modifying code: `agents-sdk-dotnet` (building/modifying agents), `agents-sdk-dotnet-debugging` (build errors, auth failures, startup crashes, config issues), and `azure-agents-sdk-provision-dotnet` (Azure Bot resources, Entra app registrations, identity credentials, OAuth connections). For migrations, also `bf-to-agents-sdk-dotnet-migration` and `agents-sdk-dotnet-activityhandler-migration`.
  - These skills are required whenever working with `Microsoft.Agents.Hosting.AspNetCore` or related Agents SDK packages (e.g. `AzureAgentToM365ATK/Program.cs`, `AzureAgentToM365ATK/Agents/AzureAgent.cs`).
- Apps and agents for Microsoft 365 or Microsoft 365 Copilot refers to applications for products in Microsoft 365, agents for Microsoft 365 Copilot, including Teams app, Office addin, declarative agent, customer engine agent, etc.
- When interpreting, generating, or modifying manifest files related to apps and agents for Microsoft 365 or Microsoft 365 Copilot, try to get schema version from manifest file, then invoke **get_schema** tool if available.
- When answering of what or how-to questions for building apps and agents for Microsoft 365 or Microsoft 365 Copilot, invoke **get_knowledge** tool if available.
- Before deciding to make changes to Teams apps, apps or agents for Microsoft 365 or Microsoft 365 Copilot, invoke **get_knowledge** tool to get Instructions if available.
- When troubleshooting issues, invoke **troubleshoot** tool if available.
- Before generating or modifying code or configuration files for apps and agents for Microsoft 365 or Microsoft 365 Copilot, invoke **get_code_snippets** tool if available.
- Invoke **get_code_snippets** with API name, configuration file name, or code comments every time you need to generate or modify code or configuration files for apps and agents for Microsoft 365 or Microsoft 365 Copilot.