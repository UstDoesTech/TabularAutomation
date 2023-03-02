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