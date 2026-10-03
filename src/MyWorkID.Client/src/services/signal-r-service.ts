import { HubConnection, HubConnectionBuilder } from "@microsoft/signalr";
import { Mutex } from "async-mutex";
import { getBearerToken } from "./msal-service";

const getVerifiedIdConnectionMutex = new Mutex();
let verifiedIdConnectionCache: HubConnection | undefined = undefined;

export const getVerifiedIdConnection = async (): Promise<HubConnection> => {
  return await getVerifiedIdConnectionMutex.runExclusive(async () => {
    if (verifiedIdConnectionCache) {
      return verifiedIdConnectionCache;
    }

    verifiedIdConnectionCache = new HubConnectionBuilder()
      .withUrl("/hubs/verifiedId", { accessTokenFactory: getBearerToken })
      .build();

    return verifiedIdConnectionCache;
  });
};
