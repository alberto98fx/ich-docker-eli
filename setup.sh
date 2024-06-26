#!/bin/bash

# install poetry in case is not there
install_poetry() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Installing Poetry on Linux..."
        curl -sSL https://install.python-poetry.org | python3 -
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Installing Poetry on macOS..."
        curl -sSL https://install.python-poetry.org | python3 -
    else
        echo "Unsupported OS. Please install Poetry manually."
        exit 1
    fi
}

# Check if Poetry is installed
if ! command -v poetry &> /dev/null; then
    echo "Poetry is not installed. Installing Poetry..."
    install_poetry
else
    echo "Poetry is already installed."
fi

# Load environment variables from .env file
export $(grep -v '^#' .env | xargs)

# Ask if we want to restore all backups or just the latest one
read -p "Do you want to restore all backups (yes/no)? Default: no" restore_all
if [[ "$restore_all" == "yes" ]]; then
    restore_flag="--all"
else
    restore_flag=""
fi

# Install Python packages using Poetry
echo "Installing Python packages with Poetry..."
poetry install # if no package need to be installed it returns a ugly red line which says "does not contain any element"

# Run the Python job with Poetry
echo "Running the Python job with Poetry..."
poetry run python generate_docker_compose.py $restore_flag

# Pull the latest MySQL image
docker pull mysql:8.0

# Start the Docker Compose environment with build
docker-compose up -d --build

echo "Waiting for MySQL containers to initialize..."
docker-compose ps  # Show the status of containers

# Get the names of all MySQL containers
mysql_containers=$(docker-compose ps --services | grep -E 'host-[0-9]{1,2}')

# Check the health status of MySQL containers
for container in $mysql_containers; do
  until [ "`docker inspect -f {{.State.Health.Status}} $container`"=="healthy" ]; do
      sleep 1;
  done;
done



echo "All MySQL instances are up and running and healthy."