using AzureAgentToM365ATK;
using AzureAgentToM365ATK.Agent;
using Microsoft.Agents.Builder;
using Microsoft.Agents.Hosting.AspNetCore;
using Microsoft.Agents.Storage;

WebApplicationBuilder builder = WebApplication.CreateBuilder(args);

if (builder.Environment.IsDevelopment())
{
    builder.Configuration.AddUserSecrets<Program>();
}

builder.Services.AddControllers();
builder.Services.AddHttpClient("WebClient", client => client.Timeout = TimeSpan.FromSeconds(600));
builder.Services.AddHttpContextAccessor();
builder.Logging.AddConsole();

// Register Semantic Kernel only used for Azure AI Foundry Agent. No LLM calls are made directly from this code.
builder.Services.AddKernel();

// Agent SDK Registrations: 
builder.Services.AddCloudAdapter();
builder.Services.AddAgentAspNetAuthentication(builder.Configuration);
builder.AddAgentApplicationOptions();
builder.AddAgent<AzureAgent>();
builder.Services.AddSingleton<IStorage, MemoryStorage>();


WebApplication app = builder.Build();


app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

// Register the agent application endpoint for incoming messages.
var incomingRoute = app.MapPost("/api/messages", async (HttpRequest request, HttpResponse response, IAgentHttpAdapter adapter, IAgent agent, CancellationToken cancellationToken) =>
{
    await adapter.ProcessAsync(request, response, agent, cancellationToken);
});

// Enabling anonymous access to the root and controller endpoints in development for testing purposes.
if (app.Environment.IsDevelopment() )
{
    app.MapGet("/", () => "Microsoft Agents SDK From Azure AI Foundry Agent Service Sample");
    app.UseDeveloperExceptionPage();
    app.MapControllers().AllowAnonymous();
}
else
{
    app.MapControllers();
}
app.Run();