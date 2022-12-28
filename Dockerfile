FROM ruby:3.1
COPY . /opt/app
WORKDIR /opt/app
RUN bundle install
CMD bundle exec rackup config.ru
