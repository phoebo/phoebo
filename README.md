# Phoebo CI

This is main component of Phoebo CI.

## Installation

For testing and development purposes please consider our [Vagrant installation](https://github.com/phoebo/vagrant).

### Requirements

The installation instructions expects following requirements to be met:

- [PostgreSQL 9.3+](http://www.postgresql.org/)
- [Redis](http://redis.io/)
- Nginx with LUA support (optional for proxy) - [Openresty](http://openresty.org/) recommended

### Preparation

```
git clone https://github.com/phoebo/phoebo.git
cd phoebo
cp config/application.yml.example config/application.yml
cp config/database.yml.example config/database.yml
```

### Configuration

Main application configuration file is at `config/application.yml`.
You need to adjust at least following:

- Gitlab server connection
- Redis server connection
- Singularity connection
- Logspout base url

Please follow commented example.

#### Gitlab server configuration

First you need to add local installation to authorized applications on your Gitlab server.

- Login to your Gitlab
- Go to **Admin area**
- Choose **Applications** from the sidebar
- Click **New Application**
- Choose whatever name you like and use `http://phoebo.local/login/callback` as a **Redirect URI**.
- Fill generated **Application id** and **Secret** into your `config/application.yml` under `gitlab_server` section.

Example:

```yaml
  gitlab_server:
    url: 'https://gitlab.v3net.cz'
    app_id: 'd1d81fe3ac22d3a3a3727cde45e9bc3cb0c687c3f1b41fff7eb9e1bfc0262cc6'
    app_secret: 'da5481096aefac072146618e404cf952a9a6a9008d163b9547e658daa21208ae'
```

#### Database configuration

Edit your `config/database.yml` to match your database server setup. To see how check [the Rails database configuration](http://edgeguides.rubyonrails.org/configuring.html#configuring-a-database).

#### Bundle install

For installing all required gems run:

```bash
bundle install
```

#### Database migration

Once you have set up `config/database.yml` and completed bundle installation you need to create database structure from migration schema.

Run following command for each environment (production, development, test):

```bash
./bin/rake db:migrate RAILS_ENV=development
```

### Running the application server

You can start the application server by running

```bash
./bin/rails server -b 0.0.0.0
```

If you want to run Phoebo CI as a service on boot, you might want to take a look at [Puma as a service](https://github.com/puma/puma/tree/master/tools/jungle) or [sample upstart file](https://github.com/phoebo/vagrant/blob/master/Puppet/modules/phoebo_webui/templates/upstart-init.conf.erb) and [puma config](https://github.com/phoebo/vagrant/blob/master/Puppet/modules/phoebo_webui/templates/puma.rb.erb) used in Vagrant installation.

**Please note that Phoebo CI currently doesn't support forked setups (multiple workers).**

### Proxy

It is recommended that you use nginx as a Proxy for HTTPS transport and service authentication layer.

Phoebo CI comes with predefined LUA snippet for that.

Example configuration:

```nginx
upstream phoebo {
  server unix:///var/run/phoebo/puma.sock;
}

server {
    listen 80;
    server_name myphoebo.tld *.myphoebo.tld;
    location / {

        set $target 'phoebo';
        access_by_lua_file /path/to/phoebo/support/nginx/proxy_access.lua;

        proxy_pass http://$target;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

## Contact

Project is developed by Adam Staněk <adam.stanek@v3net.cz>
