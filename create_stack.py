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
    """Đọc và parse file .env, trả về danh sách biến môi trường và dictionary."""
    env_variables = []
    env_dict = {}

    with open(env_file_path, "r") as file:
        for line in file:
            line = line.strip()
            # Bỏ qua dòng trống và comment
            if not line or line.startswith("#"):
                continue
            
            # Lấy key=value từ mỗi dòng
            if "=" in line:
                key, value = line.split("=", 1)
                key = key.strip()
                value = value.strip()
                
                # Bỏ qua dòng không có giá trị
                if key and value:
                    env_variables.append({"name": key, "value": value})
                    env_dict[key] = value

    print(f"✅ Loaded {len(env_variables)} environment variables")
    return env_variables, env_dict


def process_compose_file(compose_file_path, env_dict):
    """Xử lý file docker-compose.yml để thay thế các biến môi trường."""
    import re
    import os

    with open(compose_file_path, "r") as file:
        compose_content = file.read()
    
    # Thay thế các biến môi trường dạng ${VAR:-default}
    def replace_env_var(match):
        var_name = match.group(1)
        default_value = None
        
        # Kiểm tra xem có giá trị mặc định không
        if ":-" in var_name:
            var_name, default_value = var_name.split(":-", 1)
        
        # Ưu tiên sử dụng giá trị từ env_dict
        if var_name in env_dict:
            return env_dict[var_name]
        # Sau đó kiểm tra biến môi trường hệ thống
        elif var_name in os.environ:
            return os.environ[var_name]
        # Cuối cùng dùng giá trị mặc định nếu có
        elif default_value is not None:
            return default_value
        # Nếu không có giá trị, giữ nguyên biến
        else:
            return "${" + var_name + "}"
    
    # Thay thế các biến ${...}
    processed_content = re.sub(r'\${([^}]+)}', replace_env_var, compose_content)
    
    print("✅ Processed docker-compose.yml with environment variables")
    return processed_content


def deploy_stack(auth_token, env_id, env_variables, env_dict):
    """Triển khai stack mới từ file docker-compose.yml đã xử lý biến môi trường."""
    headers = {"Authorization": f"Bearer {auth_token}"}
    payload = {
        "Name": STACK_NAME,
        "Env": json.dumps(env_variables),
        "endpointId": env_id,
    }

    # Xử lý file docker-compose để thay thế các biến môi trường
    processed_compose = process_compose_file(STACK_FILE_PATH, env_dict)
    print(processed_compose)

    # Sử dụng nội dung đã xử lý thay vì mở file trực tiếp
    files = {"file": ("docker-compose.yml", processed_compose.encode('utf-8'))}
    print(files)

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

    env_variables, env_dict = parse_env_file(ENV_FILE_PATH)
    deploy_stack(token, env_id, env_variables, env_dict)
