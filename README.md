## Cedilla Service Implementations For The Delivery Aggregator

The services contained within this project are intended for use with the (Cedilla Delivery Aggregator)[https://github.com/cdlib/cedilla_delivery_aggregator]. 

Each service is meant to run on its own webserver listening to the port you specify. You could however easily set them up to run together by simply creating a single Sinatra::Application that uses routes to dispatch the appropriate service (e.g. get '/cover_thing' would user the CoverThingService).

### Dependencies

- Ruby >= 2.0
- Rubygems
- Sinatra (rack, rake, thin)
- Cedilla 

### Installation

- Clone this repository
```
> git clone https://github.com/cdlib/cedilla_services
```

- Move the example yaml files to a separate directory on your machine outside of the repository (for example cedilla_services_local).
- Rename each of the configuration files to .yaml (e.g. cover_thing.yaml.example -> cover_thing.yaml). 
- Update the configuration files as necessary (e.g. enter your developer key into the 'target' property for cover_thing.yaml)

- Start the service(s)
```
> cd [directory]
> cd config
> ln -s [/path/to/your/local/yaml/files/file.yaml] [file.yaml]
> cd ..
> bundle install
> rackup config.ru -p [port]
```

It is recommended that you build a startup script for the ```> rackup config.ru -p [port]``` commands

### Notifying The Cedilla Delivery Aggregator Of Your New Service(s)

You will need to make a few minor configuration changes to your Cedilla Delivery Aggregator implementation so that it begins calling your new services. 

Remember, the Aggregator will automatically reload the configuration files as you make your changes so there is no need to restart the Aggregator application. Beware however of inadvertently entering invalid <tab> characters in the yaml config files though!

#### services.yaml

You need to update the Services configuration file so that the Aggregator knows Where your service(s) are located

```
# Service specific configurations
services:
  
  # See bottom of this file for an explanation of these values!
  tiers:
    1:
      service_test:
        enabled: true
        max_attempts: 1
        timeout: 10

        target: 'http://localhost:3101/service_test'

      sfx:
        enabled: true
        max_attempts: 1
        timeout: 10

        target: 'http://localhost:3000/worker1?name=sfx'
 
# -------------------------------------------------------------------------------
    2:
      internet_archive:
        enabled: true
        max_attempts: 1
        timeout: 5
        display_name: 'The Internet Archive'

        target: 'http://localhost:3000/worker1?name=internet_archive'

      ...

  # Explanation of the tiers definition
  # ------------------------------------------------------------------------------------------------------------------------- 
  #    tiers: 
  #      tier_[number]:                    <-- The processing tier that the service belongs to. Services are grouped into tiers 
  #                                            so that the broker can prioritize services. The lower the tier number, the sooner
  #                                            the service processes. Services in tier_one are all processed first. Any service in tier_two
  #                                            must wait for all tier_one services to either be dispatched or placed in the holding queue
  #
  #                                            tier_one typically contains services that can provide important information about the
  #                                            citation such as ISBN, DOI, or other ids that may make it possible to call additional
  #                                            services. It also typically contains services that respond quickly and provide links
  #                                            to online copies of the item.
  # -------------------------------------------------------------------------------------------------------------------------


  # Explanation of the values in a service definition
  # -------------------------------------------------------------------------------------------------------------------------
  # 
  # [name]:                                <-- The name of the service (see below for naming convention rules)
  #    enabled: [true/false]               <-- Default is 'false' if this is omitted
  #    max_attempts: [number]              <-- The number of times the endpoint will be called in the event of an HTTP error. default is 1
  #    timeout: [seconds]                  <-- The number of seconds after which the HTTP call to the service should timeout. default is 5
  #    display_name: [string]              <-- A user friendly name for the service. This name will be sent back to the client app. default is [name]
  #
  #    target: [string]                    <-- The HTTP address of the service. This value should include the http:// or https:// prefix!
  # -------------------------------------------------------------------------------------------------------------------------
```

#### rules.yaml

You need to update the Rules configuration file so that the Aggregator knows when it is appropriate to contact your service(s)

```
objects:
  citation:
    # Group services into the genres they can search
    # When a citation comes in from a client the rules engine will use this list to determine what
    # services the broker will dispatch. For example the cover_open_library service can only provide
    # results for books so it should only appear in the book and bookitem genre types
    genre:
      journal:
        - sfx
        - cover_elsevier
        - cover_open_library
      book:
        - sfx
        - internet_archive
        - cover_thing
        - cover_open_library

    ...
    # Group services into the type of content they can provide
    # When a citation comes in from a client the rules engine will use this list to determine what
    # services the broker will dispatch. For example the internet_archive service can only provide
    # results for electronic and audio copies of an item so it should NOT be found in the holdings
    # category!
    content_type:
      full_text:
        - sfx
        - internet_archive
        - cover_thing
        - cover_elsevier
        - cover_open_library

    ...

# Define the minimum amount of citation information required to process a service. The options MUST match attributes on the Citation object!
# Items within an array indicate an OR relationship and items on different lines indicate an AND relationship so:
#
#    article:
#      - 'article_title'
#      - ['title', 'journal_title']
#
#   Translates to:  citation includes -> an Article Title AND (a Title OR a Journal Title)
#
# You may also use the AUTHOR keyword to indicate that the citation must have at least one author
#
#    book:
#      - ['title', 'article_title']
#      - ['AUTHOR']
#
# ==============================================================================================================================================
# WARNING!!!
#   Changes to this section will impact: test_citation.test_dispatchable, test_rules.test_has_minimum_citation_requirements
# ==============================================================================================================================================
minimum_item_groups:
  service_test:
    - ['isbn', 'eisbn']
  internet_archive:
    - ['title', 'book_title']
    - ['AUTHOR']
  sfx:
    - ['title', 'journal_title', 'book_title', 'article_title', 'series_title', 'issn', 'eissn', 'isbn', 'eisbn', 'oclc', 'lccn', 'doi', 'pmid', 'coden', 'sici', 'bici', 'document_id']
  cover_thing:
    - ['isbn', 'eisbn'] 

  ...
```

## License

The Cedilla Services Project adheres to the [BSD 3 Clause](./LICENSE.md) license agreement.