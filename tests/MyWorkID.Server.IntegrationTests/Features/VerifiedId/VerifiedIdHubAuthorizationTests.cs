using FluentAssertions;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using MyWorkID.Server.IntegrationTests.Authentication;
using System.Net;

namespace MyWorkID.Server.IntegrationTests.Features.VerifiedId;

public class VerifiedIdHubAuthorizationTests
{
    [Fact]
    public async Task AnonymousNegotiationWithAnObjectIdQuery_IsRejected()
    {
        using var factory = new TestApplicationFactory();
        using var client = factory.CreateClient();
        var response = await client.PostAsync($"/hubs/verifiedId/negotiate?negotiateVersion=1&access_token={Guid.NewGuid()}", null);

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task AuthenticatedNegotiation_IsAllowed()
    {
        using var factory = new TestApplicationFactory();
        using var client = factory.WithAuthentication(new TestClaimsProvider().WithRandomSubAndOid()).CreateClient();
        var response = await client.PostAsync("/hubs/verifiedId/negotiate?negotiateVersion=1", null);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task QueryBearerToken_IsOnlyReadOnVerifiedIdHubPath()
    {
        using var factory = new TestApplicationFactory();
        using var client = factory.CreateClient();
        var options = factory.Services.GetRequiredService<IOptionsMonitor<JwtBearerOptions>>().Get(JwtBearerDefaults.AuthenticationScheme);
        var scheme = new AuthenticationScheme(JwtBearerDefaults.AuthenticationScheme, null, typeof(JwtBearerHandler));

        var hubRequest = new DefaultHttpContext();
        hubRequest.Request.Path = "/hubs/verifiedId";
        hubRequest.Request.QueryString = new QueryString("?access_token=test-token");
        var hubContext = new MessageReceivedContext(hubRequest, scheme, options);
        await options.Events.OnMessageReceived(hubContext);
        hubContext.Token.Should().Be("test-token");

        var apiRequest = new DefaultHttpContext();
        apiRequest.Request.Path = "/api/me/verifiedId/verify";
        apiRequest.Request.QueryString = new QueryString("?access_token=test-token");
        var apiContext = new MessageReceivedContext(apiRequest, scheme, options);
        await options.Events.OnMessageReceived(apiContext);
        apiContext.Token.Should().BeNull();
    }
}
