## Hiera Eyaml Frontend

### Description:

A tiny Webserver, written in ruby that manages two endpoints:
    
    '/'        => { verb: GET }
    '/encrypt' => { verb: POST }

The scope of this server is to have a graphical frontend over the command line tool Hiera-Eyaml

This can be deployed sperately from your puppet infrastructure

The only constraint is to deploy it alongside your eyaml public key.


#### List of positional arguments
  1. Proto. The protocol used by the server, valid options are http or https (default: https)
  2. Port. The port where the webserver will listen to (default: 8081)

#### Requirements
  - Ruby core
  - Ruby stdlib (Socket, Openssl, Thread, Cgi, Erb and Time)
  - Hiera-eyaml gem
  - A valid pkcs7 public key used for encryption
  - A valid cert, key and ca for tls context

#### Setup Stuff
  - Clone the repository wherever you like
  - Copy the public_key.pkcs7.pem from your puppet under static/pubkey/ directory (to generate it simply run ``` eyaml createkeys ```)
  - If using https, copy your valid cert key and ca under certs/cert.pem, certs/key.pem and certs/ca.pem respectively
      
  note: if you want to use EC instead of RSA, just remember to use OpenSSL::PKey::EC class and add ecdh_curves as SSLContext attribute

#### Usage
/path/to/ruby /path/to/eyaml_ws.rb $Proto $Port