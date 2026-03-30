# SpinaCMS Rails Dockerized Environment

Dockerized local dev setup for [Spina CMS](https://github.com/SpinaCMS/Spina) on Rails. Everything runs in Docker.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (includes Docker Compose)
- `make` and `curl`
- Port 3000 free on localhost

## Getting Started

```bash
git clone https://github.com/munir-sayani/spina-cms-docker.git && cd spina-cms-docker

# builds containers, starts everything, then runs the Spina installer
make install
```

The installer will ask for a site name, theme (pick `default`), admin email, and password.

When it's done:
- http://127.0.0.1:3000 (default Spina page)
- http://127.0.0.1:3000/admin (admin panel)

## Useful Commands

```bash
make help           # list all targets
make up             # start services (no rebuild)
make down           # stop everything
make build          # rebuild the image
make logs           # tail the web container logs
make bundle-update  # bundle update inside the container
make clean          # nuke volumes + generated Spina files, start over
```

Adding a gem:
```bash
# edit Gemfile on your host, then:
docker compose exec web bundle install
```

Rails console / shell:
```bash
docker compose exec web bundle exec rails console
docker compose exec web bash
```

## Design Decisions

The Dockerfile is single-stage on purpose. A production image would use multi-stage to strip out compilers and dev headers, but here we need them at runtime so that `bundle install` can compile native extensions inside the container.

For the Postgres dependency I went with a `pg_isready` healthcheck + `condition: service_healthy` in compose rather than a sleep loop or wait-for-it script. Got this from the [Compose docs](https://docs.docker.com/reference/compose-file/services/#depends_on). More reliable and doesn't require guessing how long Postgres takes to start.

The app directory is bind-mounted so code changes on the host show up immediately. Gems live in a separate named volume (`bundle_cache`) so they survive container rebuilds, otherwise you'd be reinstalling everything after every `docker compose build`.

I considered automating `spina:install` with seeds and scripts but it generates a bunch of config files, migrations, and views. Easier to just run it interactively through `docker compose exec` and let Spina do its thing.

The container runs as root because of the bind mount. Host files keep their ownership and hardcoding UID 1000 breaks on machines where the host user has a different UID. For production you'd add a non-root user since there's no bind mount

Using HTTP only and Postgres trust auth per the challenge guidelines. `SECRET_KEY_BASE` is a static string for local dev.

## Challenges I Ran Into

The biggest headache was the Docker volume mount ordering. The Dockerfile builds gems into `/usr/local/bundle`, but at runtime the named volume shadows that path so on first run the gems aren't there. The entrypoint has to run `bundle install` to populate the volume.

Also hit migration conflicts when testing `make clean && make install`. Cleaning the Postgres volume but leaving Spina's generated migration files on disk caused `DuplicateTable` errors on reinstall. Fixed it by having `make clean` also remove the generated Spina files (migrations, initializers, views).

The `psych` gem needed `libyaml-dev` which isn't in `ruby:slim` images. This one wasn't obvious until I dug into the build logs.

## Known Caveats

- First `make install` is slow since it's installing all gems into an empty volume. After that, `make up` is fast.
- You might see a `Cannot apply unknown utility class 'font-body'` warning during install. It's a Spina v2.20 / Tailwind v4 compat thing. Cosmetic as admin panel works fine.
- Trust auth and the static secret key are dev only. Don't use either in production.

## What I'd Do Next

The main thing would be a proper production Dockerfile with multi-stage build, non-root user, asset precompilation. I'd also pin Ruby to a specific patch version instead of just 3.2.

For AWS I'd probably go with ECS Fargate + RDS, and move ActiveStorage uploads to S3. Terraform for the infra. The compose file would stay as the local dev setup.

Would also want some kind of CI to at least build the image and verify it starts up cleanly before merging.

## References

- https://docs.docker.com/guides/ruby/containerize/
- https://docs.docker.com/reference/compose-file/services/
- https://hub.docker.com/_/postgres
- https://github.com/SpinaCMS/Spina
