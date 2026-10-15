using System.Net;
using System.Net.Http.Headers;
using Microsoft.Kiota.Http.HttpClientLibrary.Middleware;

namespace MyWorkID.Server.UnitTests.Security;

public class KiotaRedirectTests
{
    [Theory]
    [InlineData("https://redirect.example/final", false)]
    [InlineData("https://graph.microsoft.com/final", true)]
    public async Task RedirectsScrubSensitiveHeadersWhenTheHostChanges(
        string destination, bool sameHost)
    {
        var terminal = new RedirectResponseHandler(new Uri(destination));
        using var invoker = new HttpMessageInvoker(new RedirectHandler
        {
            InnerHandler = terminal
        });
        using var request = new HttpRequestMessage(HttpMethod.Get, "https://graph.microsoft.com/start");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", "placeholder-token");
        request.Headers.ProxyAuthorization = new AuthenticationHeaderValue("Basic", "placeholder-proxy");
        request.Headers.Add("Cookie", "session=placeholder");

        using var response = await invoker.SendAsync(request, CancellationToken.None);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(2, terminal.Calls);
        Assert.Equal(new Uri(destination), terminal.FinalUri);
        Assert.Equal(sameHost ? "Bearer placeholder-token" : null, terminal.Authorization);
        Assert.Equal(sameHost ? "session=placeholder" : null, terminal.Cookie);
        Assert.Null(terminal.ProxyAuthorization);
    }

    private sealed class RedirectResponseHandler(Uri destination) : HttpMessageHandler
    {
        public int Calls { get; private set; }
        public Uri? FinalUri { get; private set; }
        public string? Authorization { get; private set; }
        public string? ProxyAuthorization { get; private set; }
        public string? Cookie { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Calls++;
            if (Calls == 1)
            {
                var redirect = new HttpResponseMessage(HttpStatusCode.Found) { RequestMessage = request };
                redirect.Headers.Location = destination;
                return Task.FromResult(redirect);
            }

            if (Calls != 2)
                throw new InvalidOperationException("Unexpected redirect hop.");

            FinalUri = request.RequestUri;
            Authorization = request.Headers.Authorization?.ToString();
            ProxyAuthorization = request.Headers.ProxyAuthorization?.ToString();
            Cookie = request.Headers.TryGetValues("Cookie", out var values) ? string.Join("; ", values) : null;
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { RequestMessage = request });
        }
    }
}
