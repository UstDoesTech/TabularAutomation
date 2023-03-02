import os
import json

file_location = "../JsonTemplates/"
file_name = 'AdventureworksTabular_LARGE.json'

# print(data)

def get_file_path(file_location, file_name):
    file_path = os.path.join(file_location, file_name)
    return file_path

def get_tabular_template(file_path):
    with open(file_path) as data_file:
        data = json.load(data_file)
    return data

def convert_json_to_string(data):
    data_string = json.dumps(data)
    return data_string

def convert_string_to_json(data_string):
    data = json.loads(data_string)
    return data

def get_filtered_database_name(database_name, month, year):
    return database_name + " " + month + " " + year

def replace_template_placeholders(tabular_template, placeholder, value):
    tabular_template = tabular_template.replace(placeholder, value)
    return tabular_template

database_name = "AdventureWorksFilteredModel"
month = "May"
year = "2013"

filtered_database_name = get_filtered_database_name(database_name, month, year)
print(filtered_database_name)

file_path = get_file_path(file_location, file_name)
print(file_path)

tabular_template = get_tabular_template(file_path)
tabular_template = convert_json_to_string(tabular_template)

tabular_template = replace_template_placeholders(tabular_template, "%MONTH%", month)
tabular_template = replace_template_placeholders(tabular_template, "%YEAR%", year)
tabular_template = replace_template_placeholders(tabular_template, "%DATABASENAME%", filtered_database_name)

tabular_template = convert_string_to_json(tabular_template)

print(tabular_template)

# $impersonationMode = "impersonateAccount"
# #$account = "DOMAIN\\USERNAME"
# #$password = "PASSWORD"

# # AAS: Provider=MSOLAP;Data Source=asazure://westeurope.asazure.windows.net/adventureworksssas;Initial Catalog=<Initial Catalog>
# $serverName = "localhost"
# # Refresh options for database are: full clearValues calculate dataOnly automatic defragment
# $refreshType = "automatic"

# # Deploy the new database
# Invoke-ASCmd –InputFile "$tabularModelDeploymentLocation $databaseName.json" -Server $serverName
# # Process the new database
# Invoke-ASCmd -Server $serverName -Query "{""refresh"":{""type"": ""$refreshType"", ""objects"": [{""database"": ""$databaseName""}]}}"

