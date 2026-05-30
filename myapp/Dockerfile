FROM python:3.14-slim

WORKDIR /code

COPY requirements.txt /code/requirements.txt

RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

COPY . /code/myapp

CMD ["fastapi", "run", "myapp/main.py", "--port", "80"]