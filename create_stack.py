# %%
import os
import json
import requests
import getpass
from dotenv import load_dotenv

# %%
# Portainer API base URL

# input_ip = input("Input IP Portainer: ")

#base_url = f'https://{input_ip}:9443/api'
base_url = f'https://localhost:9443/api'


# Authentication endpoint
auth_endpoint = '/auth'

# Replace with your Portainer username and password
username = 'admin'
#password = getpass.getpass("Input Password: ")
password= 'Wl+jVfl5l3m9tM24'
# Create a session
session = requests.Session()

# Prepare authentication payload
auth_payload = {
    "Username": username,
    "Password": password
}

# Replace with the name of your stack
#stack_name = input("Input Stack Name: ")
stack_name = 'monitor'
# %%
# Make the POST request to authenticate
response = session.post(f"{base_url}{auth_endpoint}", json=auth_payload,verify=False)

# Check the response status code
if response.status_code == 200:
    print("Authentication successful")

    # Parse the JSON response
    auth_data = response.json()

    # Access and print individual values
    auth_token = auth_data.get("jwt", "")
    
    print(f"Access Token: {auth_token}")

    # You can now use the session for authenticated requests
else:
    print(f"Authentication failed with status code: {response.status_code}")
    print(response.json())  # Print the response content for debugging

# %%
# Endpoint for listing all endpoints
endpoint_list_endpoint = '/endpoints'

# Create a session with the authorization header
headers = {
    'Authorization': f'Bearer {auth_token}',
}

# %%
# Make the GET request to list endpoints
response = requests.get(f"{base_url}{endpoint_list_endpoint}", headers=headers, verify=False)

# Check the response status code
if response.status_code == 200:
    print("Endpoints listed successfully")
    
    # Parse the JSON response
    endpoints_data = response.json()

    # Access and work with the endpoint data as needed
    for endpoint in endpoints_data:
        print(f"Endpoint ID: {endpoint['Id']}")
        print(f"Endpoint Name: {endpoint['Name']}")
        if endpoint['Name'] == "primary":
            local_enviroment_id = f"{endpoint['Id']}"
        # Add more attributes as needed
else:
    print(f"Failed to list endpoints with status code: {response.status_code}")
    print(response.json())  # Print the response content for debugging

# %%
# Endpoint for creating a standalone stack from a file
stack_create_endpoint = '/stacks/create/standalone/file'

# Replace with your Portainer authentication token (JWT)
# auth_token = 'your_jwt_token_here'

# Replace with the name of your stack
# stack_name = 'ElasticStack'

# Replace with the environment ID where you want to deploy the stack
# local_environment_id = 123  # Replace with the actual environment ID

# Prepare the request headers with the authorization token
# headers = {
#     'Authorization': f'Bearer {auth_token}',
# }

# Name of the .env file
env_file = ".env"

# Flag to check if the "# My ENV" comment has been found
found_my_env = False

# List to store the environment variables
env_variables = []

with open(env_file, "r") as file:
    lines = file.readlines()
    for line in lines:
        line = line.strip()
        if line.startswith("# My ENV"):
            found_my_env = True
        elif found_my_env and "=" in line:
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip()
            env_variables.append({"name": key, "value": value})

# Print the list of environment variables and their values
# for variable in env_variables:
#     print(f"{variable['name']}: {variable['value']}")

# Convert the list of environment variables to a JSON string
env_json = json.dumps(env_variables)

# Prepare the request payload as multipart/form-data
payload = {
    'Name': stack_name,
    'Env': env_json,  # Use the formatted environment variables
    'endpointId': local_enviroment_id,
}

# Add the stack file to the payload
files = {
    'file': ('docker-compose.yml', open('./stacks/monitoring/docker-compose.yml', 'rb'))  # Replace 'stack.yml' and 'path/to/stack.yml' with your stack file
}

# %%
# Make the POST request to deploy the stack
response = requests.post(f"{base_url}{stack_create_endpoint}", headers=headers, data=payload, files=files,verify=False)

# Check the response status code
if response.status_code == 200:
    print("Stack deployment successful")
    
    # Parse the JSON response
    stack_data = response.json()

    # Access and work with the stack data as needed
    print(f"Stack ID: {stack_data['Id']}")
    print(f"Stack Name: {stack_data['Name']}")
    # Add more attributes as needed
else:
    print(f"Failed to deploy the stack with status code: {response.status_code}")
    print(response.json())  # Print the response content for debugging