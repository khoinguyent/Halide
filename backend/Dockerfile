FROM python:3.12-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .
# macOS tar can add AppleDouble `._*.py` next to real migrations; Alembic loads every
# `*.py` under alembic/versions and those files contain NUL bytes → SyntaxError.
RUN find /app/alembic/versions -name '._*.py' -delete 2>/dev/null || true

# Expose port
EXPOSE 8000

# Run with uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
