import msal 
import requests

class Auth:
    def __init__(self, client_id, client_secret, authority):
        self.client_id = client_id
        self.client_secret = client_secret
        self.authority = authority
        self.scope = ["https://analysis.windows.net/powerbi/api/.default"]
        self.app = msal.ConfidentialClientApplication(
            self.client_id, 
            authority=self.authority,
            client_credential=self.client_secret
        )

    def get_token(self):
        result = None

        # First, the code looks up a token from the cache
        result = self.app.acquire_token_silent(self.scope, account=None)

        # If no suitable token exists in the cache, then a new one is acquired from AAD.
        if not result:
            print("No suitable token exists in cache. Let's get a new one from AAD.")
            result = self.app.acquire_token_for_client(scopes=self.scope)

        if "access_token" in result:
            return result["access_token"]
        else:
            print(result.get("error"))
            print(result.get("error_description"))
            print(result.get("correlation_id"))  # You may need this when reporting a bug

    def get_header(self):
        access_token = self.get_token()
        header = {'Content-Type':'application/json', 'Authorization':f'Bearer {access_token}'}
        return header