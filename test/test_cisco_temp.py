import paramiko
import time
import os
import re
import sys

# --- Thông tin kết nối và xác thực ---
# Load environment variables from .env file in the same directory
from dotenv import load_dotenv
import os

# Load .env file from the same directory as this script
script_dir = os.path.dirname(os.path.abspath(__file__))
env_path = os.path.join(script_dir, '.env')
load_dotenv(env_path)

CISCO_HOST = os.getenv('CISCO_HOST', '172.18.10.4')
CISCO_PORT = int(os.getenv('CISCO_PORT', 22))

CISCO_USERNAME = os.getenv('CISCO_USERNAME', 'hissc_poe4')
CISCO_PASSWORD = os.getenv('CISCO_PASSWORD', 'Hissc@20222023')

CISCO_ENABLE_PASSWORD = os.getenv('CISCO_ENABLE_PASSWORD', '')