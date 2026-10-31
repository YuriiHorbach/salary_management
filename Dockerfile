# syntax = docker/dockerfile:1

ARG RUBY_VERSION=3.4.12
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

ENV RAILS_ENV="development" \
    BUNDLE_PATH="/usr/local/bundle"

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libvips pkg-config libyaml-dev

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .

FROM base

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libvips postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER rails:rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000

CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
