ENV['RACK_ENV'] = 'test'
$LOAD_PATH.unshift(File.absolute_path(File.join(File.dirname(__FILE__), '../')))

require 'rubygems'
require 'minitest/autorun'
require 'webmock/minitest'

require 'sinatra'
require 'yaml'

require 'rdf/turtle'
require 'rdf/rdfxml'
require 'rest_client'

require 'cedilla'

INVALID_JSONS = ['{"time":"2014-04-21T22:33:02.947Z"}',
                  '{"time":"2014-04-21T22:33:02.947Z","api_ver":"1.1"}',
                  '{"time":"2014-04-21T22:33:02.947Z","id":"123456"}',
                  '{"api_ver":"1.1","id":"123456"}',
                  '{"time":"2014-04-21T22:33:02.947Z","api_ver":"1.1","id":"123456"}',
                  '{"time":"ABCD"}',
                  '{"api_ver":"ABCD"}']

BOOK_JSON = '{"time":"2014-04-21T22:33:02.947Z",' +
              '"id":"ABCD1234",' +
              '"api_ver":"1.1",' +
              '"referrers":["google.com","domain.org"],' +
              '"requestor_ip":"127.0.0.1",' +
              '"requestor_affiliation":"CAMPUS-A",' +
              '"requestor_language":"fr",' +
              '"unmapped":"pid=institute:info/SOMEWHERE&foo=bar",' +
              '"original_request":"pid=institute:info/SOMEWHERE&rft.genre=book&rft.title=A+Tale+Of+Two+Cities&rft.au_first=Charles&rft.au_last=Dickens&rft.au=Doe%2C%20John&rft.au=Jane%20Doe%201910-1985&foo=bar",' + 
              '"citation":{"genre":"journal",' +
                          '"title":"A Tale Of Two Cities",' +
                          '"content_type":"full_text",' +
                          '"authors":[{"last_name":"Dickens","first_name":"Charles"},' +
                                     '{"full_name":"Doe, John"},' +
                                     '{"full_name":"Jane Doe 1910-1985"}]}}'
                                     
JOURNAL_JSON = '{"time":"2014-06-30T23:11:11.301Z",' +
                 '"id":"123456",' +
                 '"api_ver":"1.1",' +
                 '"requestor_ip":"127.0.0.1",' +
                 '"unmapped":"url_ver=Z39.88-2004&rfr_id=info:sid/my.domain.org:worldcat&rft_val_fmt=info:ofi/fmt:kev:mtx:journal&req_dat=<sessionid>&rfe_dat=<accessionnumber>9506582</accessionnumber>&rft_id=info:oclcnum/9506582,urn:ISSN:0737-9323&req_id=info:rfa/oclc/Institutions/123",' +
                 '"original_request":"url_ver=Z39.88-2004&rfr_id=info:sid/my.domain.org:worldcat&rft_val_fmt=info:ofi/fmt:kev:mtx:journal&req_dat=<sessionid>&rfe_dat=<accessionnumber>9506582</accessionnumber>&rft_id=info:oclcnum/9506582&rft_id=urn:ISSN:0737-9323&rft.jtitle=Journal+of+historical+linguistics+&+philology.&rft.issn=0737-9323&rft.place=Ann+Arbor++Mich.&rft.pub=Karoma+Publishers&rft.genre=journal&req_id=info:rfa/oclc/Institutions/1234",' +
                 '"citation":{"journal_title":"Journal of historical linguistics ",' +
                             '"issn":"0737-9323",' +
                             '"publication_place":"Ann Arbor  Mich.",' +
                             '"publisher":"Karoma Publishers",' +
                             '"genre":"journal",' +
                             '"content_type":"full_text",' +
                             '"oclc":"9506582"}}'
    
ARTICLE_JSON = '{"time":"2014-06-30T23:11:11.304Z",' +
                 '"id":"123456",' +
                 '"api_ver":"1.1",' +
                 '"requestor_ip":"127.0.0.1",' +
                 '"unmapped":"xxx=yyy&id=pmid:18574385&sid=SYSTEM-Entrez:PubMed:3.1&pid=institute=CAMPUS-A&placeOfPublication=Frederick, MD",' +
                 '"original_request":"xxx=yyy&id=pmid:18574385&sid=SYSTEM-Entrez:PubMed:3.1&volume=31&aulast=Major&atitle=Involvement of general practice (family medicine) in undergraduate medical education in the United kingdom.&spage=269&issn=0148-9917&issue=3&genre=article&auinit=SC&aufirst=Stella C&epage=75&title=The+Journal+of+ambulatory+care+management&year=2008&pid=institute=CAMPUS-A&placeOfPublication=Frederick%2c+MD&publisher=Aspen+Publishers%2c+Inc.",' +
                 '"citation":{"authors":[{"last_name":"Major","initials":"SC","first_name":"Stella C"}],' +
                             '"volume":"31",' +
                             '"article_title":"Involvement of general practice (family medicine) in undergraduate medical education in the United kingdom.",' +
                             '"start_page":"269",' +
                             '"issn":"0148-9917",' +
                             '"issue":"3",' +
                             '"genre":"article",' +
                             '"end_page":"75",' +
                             '"title":"The Journal of ambulatory care management",' +
                             '"year":"2008",' +
                             '"publisher":"Aspen Publishers, Inc.",' +
                             '"content_type":"full_text",' +
                             '"pmid":"18574385",' +
                             '"publication_place":"Frederick, MD"}}'

CHAPTER_JSON = '{"time":"2014-06-30T23:11:11.486Z",' +
                 '"id":"123456",' +
                 '"api_ver":"1.1",' +
                 '"requestor_ip":"127.0.0.1",' +
                 '"unmapped":"sid=SYSTEM-OVID:inspdb:5.19&pid=institute=CAMPUS-A",' +
                 '"original_request":"sid=SYSTEM-OVID:inspdb:5.19&aulast=McCandless&atitle=Glancing incidence X-ray diffraction of polycrystalline thin films&spage=75&genre=bookitem&isbn=1-55899-818-7&title=Thin-Film+Compound+Semiconductor+Photovoltaics&pid=institute=CAMPUS-A",' +
                 '"citation":{"authors":[{"last_name":"McCandless"}],' +
                             '"article_title":"Glancing incidence X-ray diffraction of polycrystalline thin films",' +
                             '"start_page":"75",' +
                             '"genre":"bookitem",' +
                             '"isbn":"1-55899-818-7",' +
                             '"title":"Thin-Film Compound Semiconductor Photovoltaics",' +
                             '"content_type":"full_text"}}'