FROM python:3.10

# zsh
RUN apt-get update
RUN apt-get install -y zsh nano
RUN sh -c "$(wget https://raw.github.com/….sh -O -)"
RUN git config --global oh-my-zsh.hide-dirty 1

RUN pip install dbt-snowflake
RUN pip install sqlfluff sqlfluff-templater-dbt

EXPOSE 8080

WORKDIR /dbt/
