# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Set environment variables to disable bytecode generation and ensure logs are flushed immediately
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set the working directory inside the container
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    python3-dev \
    libpq-dev \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libjpeg-dev \
    libxml2-dev \
    libxslt1-dev \
    sqlite3 \
    curl \ 
    jq \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# ipinfo-cli - auto install

# Install ipinfo
RUN curl -sSfL https://github.com/ipinfo/cli/releases/download/ipinfo-3.3.1/deb.sh | sh 


# Upgrade pip to the latest version
RUN pip install --upgrade pip

# Copy the requirements file and install dependencies
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the project code
COPY . /app/

# Expose port 7070 for the Django application
EXPOSE 7070

# Collect static files, apply migrations, and start the Django server
CMD ["sh", "-c", "python manage.py collectstatic --noinput && python manage.py migrate && python manage.py runserver 0.0.0.0:7070"]
