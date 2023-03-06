import requests
import auth

class Workspace:
    def __init__(self, workspace_name):
        self.workspace_name = workspace_name
        self.workspace_id = self.get_workspace_id()

    def get_workspace_id(self):
        url = f"https://api.powerbi.com/v1.0/myorg/groups"
        header = auth.get_header()
        response = requests.get(url, headers=header)
        response_json = response.json()
        for workspace in response_json["value"]:
            if workspace["name"] == self.workspace_name:
                return workspace["id"]
            else:
                return None
            
    def add_user(self, identifier, user_role, principal_type):
        url = f"https://api.powerbi.com/v1.0/myorg/groups/{self.workspace_id}/users"
        header = auth.get_header()
        if principal_type.lower() == "app":
            payload = {
                        "identifier": identifier,
                        "groupUserAccessRight": user_role,
                        "principalType": principal_type
                    }
        elif principal_type.lower() == "user":
            payload = {
                        "emailAddress": identifier,
                        "groupUserAccessRight": user_role,
                        "principalType": principal_type
                    }
        response = requests.post(url, headers=header, json=payload)
        response_json = response.json()
        return response_json
    
    def add_workspace(self):
        url = f"https://api.powerbi.com/v1.0/myorg/groups?workspaceV2=True"
        header = auth.get_header()
        payload = {
                    "name": self.workspace_name
                }
        response = requests.post(url, headers=header, json=payload)
        response_json = response.json()
        return response_json