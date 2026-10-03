using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Connections.Features;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Logging;
using Microsoft.Graph;
using Microsoft.Kiota.Abstractions;
using MyWorkID.Server.Features.VerifiedId;
using MyWorkID.Server.Features.VerifiedId.SignalR;
using MyWorkID.Server.Options;
using NSubstitute;
using System.Security.Claims;

namespace MyWorkID.Server.UnitTests.Features.VerifiedId;

public class VerifiedIdHubTests
{
    [Fact]
    public async Task Connection_IsRegisteredOnlyForAuthenticatedObjectId()
    {
        var objectId = Guid.NewGuid().ToString();
        var repository = Substitute.For<IVerifiedIdSignalRRepository>();
        var context = NewContext(new Claim("oid", objectId));
        var hub = new VerifiedIdHub(repository) { Context = context };

        await hub.OnConnectedAsync();
        repository.Received(1).AddUser(objectId, "connection-1");

        await hub.OnDisconnectedAsync(null);
        repository.Received(1).RemoveUser(objectId, "connection-1");
    }

    [Fact]
    public async Task ConnectionWithoutObjectId_IsRejectedWithoutRegistration()
    {
        var repository = Substitute.For<IVerifiedIdSignalRRepository>();
        var hub = new VerifiedIdHub(repository) { Context = NewContext(new Claim("sub", Guid.NewGuid().ToString())) };

        await Assert.ThrowsAsync<InvalidOperationException>(() => hub.OnConnectedAsync());
        repository.DidNotReceiveWithAnyArgs().AddUser(default!, default!);
    }

    [Fact]
    public async Task VictimIdInQuery_CannotSubscribeToVictimEventsOrChangeDisconnectOwner()
    {
        var userA = Guid.NewGuid().ToString();
        var userB = Guid.NewGuid().ToString();
        var repository = new VerifiedIdSignalRRepository();
        var attackerHub = new VerifiedIdHub(repository) { Context = NewContext(new Claim("oid", userA), "connection-A", userB) };
        var victimHub = new VerifiedIdHub(repository) { Context = NewContext(new Claim("oid", userB), "connection-B") };
        Assert.Equal(userB, attackerHub.Context.GetHttpContext()?.Request.Query["access_token"].ToString());

        await attackerHub.OnConnectedAsync();
        await victimHub.OnConnectedAsync();
        Assert.True(repository.TryGetConnections(userA, out var attackerConnections));
        Assert.Equal(new[] { "connection-A" }, attackerConnections);
        Assert.True(repository.TryGetConnections(userB, out var victimConnections));
        Assert.Equal(new[] { "connection-B" }, victimConnections);

        var clients = Substitute.For<IHubClients<IVerifiedIdHub>>();
        var recipient = Substitute.For<IVerifiedIdHub>();
        recipient.HideQrCode().Returns(Task.CompletedTask);
        clients.Clients(Arg.Any<IReadOnlyList<string>>()).Returns(recipient);
        var hubContext = Substitute.For<IHubContext<VerifiedIdHub, IVerifiedIdHub>>();
        hubContext.Clients.Returns(clients);
        var service = new VerifiedIdService(new HttpClient(), Microsoft.Extensions.Options.Options.Create(new VerifiedIdOptions()),
            new GraphServiceClient(Substitute.For<IRequestAdapter>()), repository, hubContext,
            Substitute.For<ILogger<VerifiedIdService>>());

        await service.HideQrCodeForUser(userB);
        clients.Received(1).Clients(Arg.Is<IReadOnlyList<string>>(ids => ids.Count == 1 && ids[0] == "connection-B"));
        await recipient.Received(1).HideQrCode();

        await attackerHub.OnDisconnectedAsync(null);
        Assert.True(repository.TryGetConnections(userB, out victimConnections));
        Assert.Equal(new[] { "connection-B" }, victimConnections);
        Assert.True(repository.TryGetConnections(userA, out attackerConnections));
        Assert.Empty(attackerConnections);
    }

    private static HubCallerContext NewContext(Claim claim, string connectionId = "connection-1", string? queryObjectId = null)
    {
        var context = Substitute.For<HubCallerContext>();
        context.User.Returns(new ClaimsPrincipal(new ClaimsIdentity(new[] { claim }, "Bearer")));
        context.ConnectionId.Returns(connectionId);
        context.Items.Returns(new Dictionary<object, object?>());
        var httpContext = new DefaultHttpContext();
        if (queryObjectId != null) httpContext.Request.QueryString = new QueryString($"?access_token={queryObjectId}");
        var httpFeature = Substitute.For<IHttpContextFeature>();
        httpFeature.HttpContext.Returns(httpContext);
        var features = new FeatureCollection();
        features.Set(httpFeature);
        context.Features.Returns(features);
        return context;
    }
}
