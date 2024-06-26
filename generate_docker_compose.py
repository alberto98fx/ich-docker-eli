import os
import glob
import argparse
from jinja2 import Environment, FileSystemLoader
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()
MYSQL_ROOT_PASSWORD = os.getenv('MYSQL_ROOT_PASSWORD')

# Directory where backups are stored
backup_dir = './backups'

# Parse command-line arguments
parser = argparse.ArgumentParser(description='Generate docker-compose.yml for MySQL backups.')
parser.add_argument('--all', action='store_true', help='Include all backups')
args = parser.parse_args()

# Find all .sql.gz files in the backups directory
backup_files = glob.glob(os.path.join(backup_dir, '*.sql.gz'))

# Function to extract hostname and timestamp from filename
def extract_info(file):
    parts = file.split('_')
    host = parts[0]
    timestamp = parts[2]
    return host, timestamp

# Group backup files by host
backups_by_host = {}
for file in backup_files:
    host, timestamp = extract_info(os.path.basename(file))
    if host not in backups_by_host:
        backups_by_host[host] = []
    backups_by_host[host].append((file, timestamp))

# Prepare data for template rendering
services = []
port = 3307
mysql_hosts = []
for host, files in backups_by_host.items():
    if args.all:
        # Include all backups
        for file, timestamp in files:
            service_name = f"{host}_{timestamp}"
            services.append({
                'name': service_name,
                'backup_path': os.path.abspath(file),
                'port': port
            })
            mysql_hosts.append(f"127.0.0.1:{port}")
            port += 1
    else:
        # Include only the latest backup
        latest_file, latest_timestamp = max(files, key=lambda x: x[1])
        service_name = f"{host}_{latest_timestamp}"
        services.append({
            'name': service_name,
            'backup_path': os.path.abspath(latest_file),
            'port': port
        })
        mysql_hosts.append(f"127.0.0.1:{port}")
        port += 1

# Load Jinja2 template
env = Environment(loader=FileSystemLoader('.'))
template = env.get_template('docker-compose-template.yml.j2')

# Render template with data
compose_content = template.render(
    services=services, 
    mysql_root_password=MYSQL_ROOT_PASSWORD,
    mysql_hosts=",".join(mysql_hosts)
)

# Write the docker-compose.yml content to a file
with open('docker-compose.yml', 'w') as file:
    file.write(compose_content)

print("docker-compose.yml has been generated successfully.")
