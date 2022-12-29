FROM ruby:3.1
RUN apt-get update -qq && apt-get upgrade -qq \
&& apt-get clean && rm -r /var/lib/apt/lists/*
COPY Gemfile /opt/app/
COPY Gemfile.lock /opt/app/
WORKDIR /opt/app
RUN bundle install
COPY . /opt/app
CMD bundle exec rackup config.ru -o 0.0.0.0 -E production
