FROM ruby:3.1
RUN apt-get update -qq && apt-get upgrade -qq \
&& apt-get clean && rm -r /var/lib/apt/lists/*
COPY . /opt/app
WORKDIR /opt/app
RUN bundle install
CMD bundle exec rackup config.ru -o 0.0.0.0 -E production
