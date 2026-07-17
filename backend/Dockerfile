FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Install entrypoint outside /app so bind-mount ./backend:/app cannot hide it.
# Strip CRLF in case the host checked out Windows line endings.
RUN sed -i 's/\r$//' /app/entrypoint.sh \
    && cp /app/entrypoint.sh /entrypoint.sh \
    && chmod +x /entrypoint.sh

EXPOSE 8000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
