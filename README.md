# Cedilla Service Implementations For The Delivery Aggregator

## Overview

[![Build Status](https://secure.travis-ci.org/cdlib/cedilla_service_commons.png?branch=master)](http://travis-ci.org/cdlib/cedilla_services)

This project contains a collection of services that can be used to feed the Cedilla delivery aggregation system: https://github.com/cdlib/cedilla.

The project consists of a single Sinatra webserver (http://www.sinatrarb.com/), that exposes an HTTP endpoint for each of the services registered in the /config/app.yml configuration file.

The individual services are implementations of the https://github.com/cdlib/cedilla_service_commons ruby gem which provides a unified way to communicate with the cedilla system. Please see the Gem's documentation if you would like to add your own services to this project.

#### Dependencies

- Ruby >= 2.0
- Sinatra (rack, rake, thin)
- OCLC Authentication Gem (submodule of this project)
- Worldcat Discovery Gem (submodule of this project)
- Cedilla Service Commons Gem: https://github.com/cdlib/cedilla (submodule of this project)

## Installation

#### Clone this repository
```
> git clone https://github.com/cdlib/cedilla_services
```

#### Build the OCLC Submodule Gems
```
> cd cedilla_services
> git submodule init
> git submodule update

> cd vendor/oclc-auth-ruby
> gem build oclc-auth.gemspec
> gem install oclc-auth-ruby

> cd ../worldcat-discovery-ruby
> gem build worldcat-discovery.gemspec
> gem install worldcat-discovery
> cd ../..
```

#### Build the Cedilla Service Commons Gem
Skip this step if you've already installed that project seperately
```
> cd vendor/cedilla_service_commons
> gem build cedilla.gemspec
> gem install cedilla
> cd ../..
```

#### Make your own copy of the configuration file
* Move the application yaml files to a separate directory on your machine outside of the repository (for example cedilla_services_local) and rename it from app.yml.example to app.yml. Then create a link to it in the project.
```
> mkdir ../cedilla_services_local
> mv ./config/app.yml.example ../cedilla_services_local/app.yml
> cd config
> ln -s [full path to /cedilla_services_local/app.yml] app.yml
```

#### Update the configuration file. Several of the services have WSKeys, DevKeys, etc. that are unique to your institution. Update them accordingly.

#### Start the services
```
> bundle install
> thin -R config.ru start -p [port]
```

## Configuring Cedilla To Use These Services

Once your services have been installed and started, you will need to make some configuration changes to the Cedilla system so that it begins communicating with these services.

#### Make sure the services are registered in config/services.yaml
For example if we started the services on port 3104 of the same server that Cedilla is running on, we would update the Internet Archive service entry as follows (see the comments within the config for more detailed info):
```
tiers:
  1:
    # ------------------------------------------------------
    internet_archive:
      enabled: true
      max_attempts: 3
      timeout: 30000
      display_name: 'Internet Archive'

      target: 'http://localhost:3104/internet_archive'

      item_types_returned: ['resource']
      do_not_call_if_referrer_from: ['archive.org/']
```

#### Make sure that the services are registered in config/rules.yaml
Each of the services must be setup in the rules configuration file. 

It must be listed in either the dispatch_always section or be defined in the appropriate genre values. For example, if we want the SFX service to be called regardless of the genre but want Internet Archive to be called only for books we would setup the rules configuration as follows (see the comments within the config for more detailed info):
```
dispatch_always:
  - sfx

objects:
  citation:
    genre:
      book:
        - internet_archive

```

Every service MUST also have its minimum_item_groups defined unless you want Cedilla to call the service regardless of the quality of the incoming citation. For example, if the incoming citation is for the book genre but no title was provided we would likely not want to contact the Internet Archive service. To prevent this from happening you would set up the rules configuration as follows to tell Cedilla to only call the Internet Archive service if it has both an author and a title or book title (see the comments within the config for more detailed info):
```
minimum_item_groups:
  internet_archive:
    - ['title', 'book_title']
    - ['authors']
```

## Adding Your Own Services

To add your own services please use the documentation for the https://github.com/cdlib/cedilla_service_commons ruby gem. Please consider making your services available to the entire community by contributing back to this project if you think your service may be valuable to other institutions!

## License

The Cedilla Ruby Gem uses adheres to the [BSD 3 Clause](./LICENSE.md) license agreement.
