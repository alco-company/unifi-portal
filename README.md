# README

Unifi Portal is an external captive portal application bespoke built for Unifi, affording guests easy access to a guest WiFi network
by requesting the user to supply a phone number and/or email address. Unifi Portal will generate an OTP - one time password -
and forwards it on the channels (SMS/Text, email) offered by the guest.

Unifi Portal is multi-tenant and each tenant may have multiple sites (effectively allowing tenants to run more guest networks).
Tenants have many clients (network users/guests) and if a client exist (phone number known) they will get permanent access - or
at least 1,000,000 minutes

Clients have many devices and each device is registered and updated with the site currently 'attached' to when authorized.

Unifi Portal uses [Mailersend](https://mailersend.com) for email delivery and [SMSAPI](https://smsapi.com) for sending SMS/Texts.

## Installation

Clone the repo to your desktop and make a few settings in an `Rails.root/.env` file and then deploy it with [Kamal](https://kamal-deploy.org/).

Pay attention to the `db/seeds.rb` that will create a superuser account once you deploy!

Now turn your attention to the network controller. You'll need to setup the controller to use an external captive portal.

> 🪔 **Pro Tip**
>
>put in any IP4 address and then add the FQDN on the settings tab ordering Unifi to use that instead and remember to add the domain to the Pre-Authorization Allowances list of domains guests can access.

### Settings

These are the settings that you will have to consider:

```ruby
  KAMAL_REGISTRY_PASSWORD=
  SECRET_KEY_BASE=
  RAILS_MASTER_KEY=
  Unifi Portal_VERSION=0.7.2
  SSL_DOMAIN=
  SMTP_USER_NAME=
  MAILERSEND_API_TOKEN=
  MAILERSEND_API_WEBHOOK_SECRET=not_used_atm
  SMSAPI_API_TOKEN=
  PDF_HOST=not_used_atm
  WEB_HOST=
```

Most are self explanatory ones. The router and ActionMailer uses the WEB_HOST while ActionController uses the SSL_DOMAIN but you'd probably be
happy setting both to your-captive-portal-domain-name.

## Usage

Once 'live' you should create a tenant, a site, and possibly a client, to test the thing. When creating the site you will want to decide whether it will
be a 'login' or 'api' site. That decision depends on the equipment! Some Unifi controllers will require you to login to use their API while others will
let you setup an API token. Consult the documentation!

## DISCLAIMER

Unifi Portal probably could be deployed in an environment different from Unifi - go through the `app/services/external/unifi` files and make copies that will address
your environment - Cisco, Aruba, more.

The amount of tests leave quite a lot to wish for.

Unifi Portal works with Unifi gateways that offer an API_TOKEN access to the API. Unifi Portal even works with Unifi controllers installed on VM/Docker/more where
you will setup a user/password to use the API (define it on the site) but we found that timing issues will report the device as authorized yet not convince
the network on the device that it has network access 🥵

## Support

Unifi Portal is open source but if we are "guns for hire" and if your use case demands support/maintenance and a friendly face we are open to negotiate a deal
that will benefit both of us.
