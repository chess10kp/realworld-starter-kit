FROM python:3.12-slim

# Install Jac
RUN pip install jaclang

# Install uv for faster pip
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

# Copy project files
COPY main.jac jac.toml ./
COPY adapter.py ./
COPY run.sh ./

# Make run script executable
RUN chmod +x run.sh

# Pre-install Jac dependencies
RUN jac install || true

# Expose the adapter port
EXPOSE 3000

# Start both Jac server and adapter
CMD ["bash", "run.sh"]
