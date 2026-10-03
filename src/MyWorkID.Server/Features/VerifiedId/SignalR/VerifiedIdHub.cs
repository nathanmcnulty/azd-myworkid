using Microsoft.AspNetCore.SignalR;

using Microsoft.Identity.Web;
namespace MyWorkID.Server.Features.VerifiedId.SignalR
{
    /// <summary>
    /// SignalR hub for managing Verified ID operations and user connections.
    /// </summary>
    public class VerifiedIdHub : Hub<IVerifiedIdHub>
    {
        private const string ConnectedUserIdKey = "VerifiedIdConnectedUserId";
        private readonly IVerifiedIdSignalRRepository _verifiedIdSignalRRepository;

        /// <summary>
        /// Initializes a new instance of the <see cref="VerifiedIdHub"/> class with the specified repository.
        /// </summary>
        /// <param name="verifiedIdSignalRRepository">The repository used to manage user connections.</param>
        public VerifiedIdHub(IVerifiedIdSignalRRepository verifiedIdSignalRRepository)
        {
            _verifiedIdSignalRRepository = verifiedIdSignalRRepository;
        }

        /// <summary>
        /// Called when a new connection is established with the hub.
        /// </summary>
        /// <returns>A task that represents the asynchronous operation.</returns>
        public override Task OnConnectedAsync()
        {
            var userObjectId = Context.User?.GetObjectId();
            if (!Guid.TryParse(userObjectId, out var objectId) || objectId == Guid.Empty)
            {
                throw new InvalidOperationException("Authenticated user object id is missing");
            }

            Context.Items[ConnectedUserIdKey] = userObjectId;
            _verifiedIdSignalRRepository.AddUser(userObjectId!, Context.ConnectionId);
            return base.OnConnectedAsync();
        }

        /// <summary>
        /// Called when a connection with the hub is terminated.
        /// </summary>
        /// <param name="exception">The exception that occurred, if any.</param>
        /// <returns>A task that represents the asynchronous operation.</returns>
        public override Task OnDisconnectedAsync(Exception? exception)
        {
            if (Context.Items.TryGetValue(ConnectedUserIdKey, out var connectedUserId) && connectedUserId is string userObjectId)
            {
                _verifiedIdSignalRRepository.RemoveUser(userObjectId, Context.ConnectionId);
            }
            return base.OnDisconnectedAsync(exception);
        }
    }
}
