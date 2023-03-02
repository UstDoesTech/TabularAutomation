import requests
import json
import auth
import workspace

class Dataset:
    def __init__(self, dataset_name):
        self.dataset_name = dataset_name
        self.workspace_id = workspace.get_workspace_id()
        self.dataset_id = self.get_dataset_id()
        

    def get_dataset_id(self):
        url = f"https://api.powerbi.com/v1.0/myorg/groups/{self.workspace_id}/datasets"
        header = auth.get_header()
        response = requests.get(url, headers=header)
        response_json = response.json()
        for dataset in response_json["value"]:
            if dataset["name"] == self.dataset_name:
                return dataset["id"]
            else:
                return None
            
    def get_dataset(self):
        url = f"https://api.powerbi.com/v1.0/myorg/groups/{self.workspace_id}/datasets/{self.dataset_id}"
        header = auth.get_header()
        response = requests.get(url, headers=header)
        response_json = response.json()
        return response_json
    
    def get_dataset_tables(self):
        url = f"https://api.powerbi.com/v1.0/myorg/groups/{self.workspace_id}/datasets/{self.dataset_id}/tables"
        header = auth.get_header()
        response = requests.get(url, headers=header)
        response_json = response.json()
        return response_json
    
    def get_dataset_table(self, table_name):
        url = f"https://api.powerbi.com/v1.0/myorg/groups/{self.workspace_id}/datasets/{self.dataset_id}/tables/{table_name}"
        header = auth.get_header()
        response = requests.get(url, headers=header)
        response_json = response.json()
        return response_json
    
    def get_dataset_table_rows(self, table_name):
        url = f"https://api.powerbi.com/v1.0/myorg/groups/{self.workspace_id}/datasets/{self.dataset_id}/tables/{table_name}/rows"
        header = auth.get_header()
        response = requests.get(url, headers=header)
        response_json = response.json()
        return response_json
    
    def get_dataset_table_row(self, table_name, row_key):
        url = f"https://api.powerbi.com/v1.0/myorg/groups/{self.workspace_id}/datasets/{self.dataset_id}/tables/{table_name}/rows/{row_key}"
        header = auth.get_header()
        response = requests.get(url, headers=header)
        response_json = response.json()
        return response_json
    
    def get_dataset_table_row_count(self, table_name):
        url = f"https://api.powerbi.com/v1.0/myorg/groups/{self.workspace_id}/datasets/{self.dataset_id}/tables/{table_name}/rowCount"
        header = auth.get_header()
        response = requests.get(url, headers=header)
        response_json = response.json()
        return response_json
    
    def refresh_dataset(self):
        url = f"https://api.powerbi.com/v1.0/myorg/groups/{self.workspace_id}/datasets/{self.dataset_id}/refreshes"
        header = auth.get_header()
        response = requests.post(url, headers=header)
        response_json = response.json()
        return response_json
    
