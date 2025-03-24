import os
import sys
import json
from datetime import datetime
import requests
import warnings
from requests.packages.urllib3.exceptions import InsecureRequestWarning

# Bỏ qua cảnh báo HTTPS không xác thực
warnings.simplefilter("ignore", InsecureRequestWarning)

# Determine the absolute path of the script directory
PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
print(f"Project directory: {PROJECT_DIR}")

# Constants
BASE_URL = "https://localhost:9443/api"
AUTH_ENDPOINT = "/auth"
ENDPOINT_LIST_ENDPOINT = "/endpoints"
STACK_CREATE_ENDPOINT = "/stacks/create/standalone/file"

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

    print(f"✅ Loaded {len(env_variables)} environment variables from {env_file_path}")
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
    
    print(f"✅ Processed {compose_file_path} with environment variables")
    return processed_content

def deploy_stack(auth_token, env_id, stack_name, compose_file_path, env_file_path):
    """Triển khai stack mới từ file docker-compose.yml đã xử lý biến môi trường."""
    # Parse env file
    env_variables, env_dict = parse_env_file(env_file_path)
    
    headers = {"Authorization": f"Bearer {auth_token}"}
    payload = {
        "Name": stack_name,
        "Env": json.dumps(env_variables),
        "endpointId": env_id,
    }

    # Xử lý file docker-compose để thay thế các biến môi trường
    processed_compose = process_compose_file(compose_file_path, env_dict)
    
    # Sử dụng nội dung đã xử lý thay vì mở file trực tiếp
    files = {"file": ("docker-compose.yml", processed_compose.encode('utf-8'))}

    response = requests.post(f"{BASE_URL}{STACK_CREATE_ENDPOINT}", headers=headers, data=payload, files=files, verify=False)

    if response.status_code == 200:
        stack_data = response.json()
        print(f"✅ Stack deployment successful: {stack_data['Name']} (ID: {stack_data['Id']})")
        return True
    else:
        print(f"❌ Failed to deploy stack {stack_name}: {response.status_code}")
        print(response.json())
        return False

def get_available_stacks():
    """Lấy danh sách các stack có sẵn trong thư mục /stacks, ngoại trừ folder 'portainer'."""
    stacks_dir = os.path.join(PROJECT_DIR, 'stacks')
    
    if not os.path.isdir(stacks_dir):
        print(f"❌ Stacks directory not found: {stacks_dir}")
        return []
    
    stacks = []
    for item in os.listdir(stacks_dir):
        # Bỏ qua folder 'portainer'
        if item == 'portainer':
            print(f"ℹ️ Skipping 'portainer' folder as requested")
            continue
            
        stack_dir = os.path.join(stacks_dir, item)
        
        # Kiểm tra xem có phải là thư mục không
        if not os.path.isdir(stack_dir):
            continue
            
        env_file = os.path.join(stack_dir, '.env')
        compose_file = os.path.join(stack_dir, 'docker-compose.yml')
        
        # Kiểm tra xem có đủ file .env và docker-compose.yml không
        if os.path.isfile(env_file) and os.path.isfile(compose_file):
            stacks.append({
                'name': item,
                'env_file': env_file,
                'compose_file': compose_file
            })
    
    return stacks

# Main Execution
if __name__ == "__main__":
    # Xác thực
    token = authenticate()
    if not token:
        sys.exit(1)

    # Lấy ID của environment
    env_id = get_local_environment_id(token)
    if not env_id:
        sys.exit(1)
    
    # Lấy danh sách các stack có sẵn
    available_stacks = get_available_stacks()
    
    if not available_stacks:
        print("❌ No valid stacks found in the /stacks directory")
        sys.exit(1)
    
    print(f"Found {len(available_stacks)} stacks to deploy:")
    for i, stack in enumerate(available_stacks, 1):
        print(f"{i}. {stack['name']}")
    
    # Triển khai từng stack
    success_count = 0
    for stack in available_stacks:
        print(f"\n--- Deploying stack: {stack['name']} ---")
        if deploy_stack(token, env_id, stack['name'], stack['compose_file'], stack['env_file']):
            success_count += 1
    
    print(f"\n✅ Deployed {success_count}/{len(available_stacks)} stacks successfully")