import os
import json
import requests
import warnings
from requests.packages.urllib3.exceptions import InsecureRequestWarning

# Bỏ qua cảnh báo HTTPS không xác thực
warnings.simplefilter("ignore", InsecureRequestWarning)

# Constants
BASE_URL = "https://localhost:9443/api"
AUTH_ENDPOINT = "/auth"
ENDPOINT_LIST_ENDPOINT = "/endpoints"
STACK_CREATE_ENDPOINT = "/stacks/create/standalone/file"
STACK_NAME = "monitor"
ENV_FILE_PATH = "./stacks/monitoring/.env"
STACK_FILE_PATH = "./stacks/monitoring/docker-compose.yml"

# Authentication
USERNAME = "admin"
PASSWORD = "Wl+jVfl5l3m9tM24"  # ⚠️ Không nên hardcode mật khẩu. Hãy sử dụng biến môi trường hoặc nhập thủ công.


def authenticate():
    """Xác thực và trả về JWT token nếu thành công."""
    payload = {"Username": USERNAME, "Password": PASSWORD}
    response = requests.post(f"{BASE_URL}{AUTH_ENDPOINT}", json=payload, verify=False)

    if response.status_code == 200:
        print("✅ Authentication successful")
        return response.json().get("jwt", "")
    else:
        print(f"❌ Authentication failed: {response.status_code}")
        print(response.json())
        return None


def get_local_environment_id(auth_token):
    """Lấy ID của environment có tên 'primary'."""
    headers = {"Authorization": f"Bearer {auth_token}"}
    response = requests.get(f"{BASE_URL}{ENDPOINT_LIST_ENDPOINT}", headers=headers, verify=False)

    if response.status_code == 200:
        for endpoint in response.json():
            if endpoint["Name"] == "primary":
                print(f"✅ Found 'primary' environment: ID {endpoint['Id']}")
                return endpoint["Id"]
        print("❌ No 'primary' environment found")
    else:
        print(f"❌ Failed to list environments: {response.status_code}")
        print(response.json())

    return None


def parse_env_file(env_file_path):
    """Đọc và parse file .env, trả về danh sách biến môi trường."""
    env_variables = []
    found_my_env = False

    with open(env_file_path, "r") as file:
        for line in file:
            line = line.strip()
            if line.startswith("# My ENV"):
                found_my_env = True
            elif found_my_env and "=" in line:
                key, value = line.split("=", 1)
                env_variables.append({"name": key.strip(), "value": value.strip()})

    print(f"✅ Loaded {len(env_variables)} environment variables")
    return env_variables


def deploy_stack(auth_token, env_id, env_variables):
    """Triển khai stack mới từ file docker-compose.yml."""
    headers = {"Authorization": f"Bearer {auth_token}"}
    payload = {
        "Name": STACK_NAME,
        "Env": json.dumps(env_variables),
        "endpointId": env_id,
    }

    with open(STACK_FILE_PATH, "rb") as file:
        files = {"file": ("docker-compose.yml", file)}

        response = requests.post(f"{BASE_URL}{STACK_CREATE_ENDPOINT}", headers=headers, data=payload, files=files, verify=False)

    if response.status_code == 200:
        stack_data = response.json()
        print(f"✅ Stack deployment successful: {stack_data['Name']} (ID: {stack_data['Id']})")
    else:
        print(f"❌ Failed to deploy stack: {response.status_code}")
        print(response.json())


# Main Execution
if __name__ == "__main__":
    token = authenticate()
    if not token:
        exit(1)

    env_id = get_local_environment_id(token)
    if not env_id:
        exit(1)

    env_variables = parse_env_file(ENV_FILE_PATH)
    deploy_stack(token, env_id, env_variables)
