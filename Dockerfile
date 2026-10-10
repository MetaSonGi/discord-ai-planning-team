FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app ./app
RUN useradd --uid 10001 --create-home runner && mkdir /app/data && chown runner /app/data
USER runner
CMD ["python", "-m", "app.bot"]
